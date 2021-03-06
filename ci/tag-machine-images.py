import json
import os
import re
import requests
import taskcluster
import urllib.error
import urllib.request
import yaml
#from azure.common.credentials import ServicePrincipalCredentials
from azure.identity import ClientSecretCredential
from azure.mgmt.compute import ComputeManagementClient

from cachetools import cached, TTLCache
cache = TTLCache(maxsize=100, ttl=300)


@cached(cache)
def get_commit(org, repo, revision):
    commit = next((c for c in get_commits(org, repo) if c['sha'].startswith(revision)), None)
    if commit is not None:
        return commit
    try:
        response = urllib.request.urlopen('https://api.github.com/repos/{}/{}/commits/{}'.format(org, repo, revision))
    except urllib.error.HTTPError as e:
        print('tag-machine-images/get_commits :: error code {} on commit lookup for {}/{}/{}'.format(e.code, org, repo, revision))
        print(e.read())
        exit(123 if e.code == 403 else 1)
    return json.loads(response.read().decode())

@cached(cache)
def get_commits(org, repo):
    try:
        response = urllib.request.urlopen('https://api.github.com/repos/{}/{}/commits'.format(org, repo))
    except urllib.error.HTTPError as e:
        print('tag-machine-images/get_commits :: error code {} on commits lookup for {}/{}'.format(e.code, org, repo))
        print(e.read())
        exit(123 if e.code == 403 else 1)
    return json.loads(response.read().decode())

# we don't know the machineImageRevision
# which is the cib revision responsible for having built the machine image
# we only know that it is newer than diskImageRevision
# and that the config we are interested in contains bootstrapRevision
# this implementation returns the newest config meeting those conditions
# obviously, this is less than ideal
@cached(cache)
def guess_config(key, group, diskImageRevision, bootstrapRevision):
    commits = get_commits('mozilla-platform-ops', 'cloud-image-builder')
    cut_index = next((i for i, c in enumerate(commits) if c['sha'].startswith(diskImageRevision)), len(commits) - 1)
    config = None
    sha = None
    for commit in commits[0:cut_index]:
        configUrl = 'https://raw.githubusercontent.com/mozilla-platform-ops/cloud-image-builder/{}/config/{}.yaml'.format(commit['sha'], key)
        if requests.head(configUrl).status_code == requests.codes.ok:
            try:
                config = yaml.safe_load(urllib.request.urlopen(configUrl).read().decode())
                configTargetGroup = next((t for t in config['target'] if t['group'] == group))
                deploymentId = next((tag for tag in configTargetGroup['tag'] if tag['name'] == 'deploymentId'), { 'value': None })['value']
                sourceRevision = next((tag for tag in configTargetGroup['tag'] if tag['name'] == 'sourceRevision'), { 'value': None })['value']
                print('tag-machine-images/guess_config :: observed deployment id: {}, source revision: {}, for group: {}, in config: {}'.format(deploymentId, sourceRevision, group, configUrl))
                if sourceRevision == bootstrapRevision or deploymentId == bootstrapRevision:
                    sha = commit['sha']
                    break
                else:
                    sha = None
                    config = None
            except:
                print('tag-machine-images/guess_config :: failed to parse config from: {}'.format(configUrl))
                sha = None
                config = None
    return sha, config


secretsClient = taskcluster.Secrets({ 'rootUrl': os.environ['TASKCLUSTER_PROXY_URL'] })
secret = secretsClient.get('project/relops/image-builder/dev')['secret']

platform = os.getenv('platform')
group = os.getenv('group')
key = os.getenv('key')

print('platform: {}'.format(platform))
print('group: {}'.format(group))
print('key: {}'.format(key))

if platform == 'azure':
    azureComputeManagementClient = ComputeManagementClient(
        #ServicePrincipalCredentials(
        #    client_id = secret['azure']['id'],
        #    secret = secret['azure']['key'],
        #    tenant = secret['azure']['account']),
        ClientSecretCredential(
            tenant_id=secret['azure']['account'],
            client_id=secret['azure']['id'],
            client_secret=secret['azure']['key']),
        secret['azure']['subscription'])

    pattern = re.compile('^{}-{}-([a-f0-9]{{7}})-([a-f0-9]{{7}})$'.format(group.replace('rg-', ''), key))
    images = list([x for x in azureComputeManagementClient.images.list_by_resource_group(group) if pattern.match(x.name)])
    print('tag-machine-images :: found: {} images matching pattern: {}-{}-(disk-sha)-(deployment-id)'.format(len(images), group.replace('rg-', ''), key))
    for image in images:
        diskImageRevision = pattern.search(image.name).group(1)
        bootstrapRevision = pattern.search(image.name).group(2)
        print('tag-machine-images :: image: {}, has disk image revision: {} (mozilla-platform-ops/cloud-image-builder)'.format(image.name, diskImageRevision))
        diskImageCommit = get_commit('mozilla-platform-ops', 'cloud-image-builder', diskImageRevision)
        if image.tags:
            print('tag-machine-images :: image has tags: {}'.format(', '.join(['%s: %s' % (k, v) for (k, v) in image.tags.items()])))
            print('tag-machine-images :: updating tags...')
        else:
            print('tag-machine-images :: image has no tags. creating tags...')
        machineImageCommitSha, config = guess_config(key, group, diskImageRevision, bootstrapRevision)
        if config is not None:
            print('tag-machine-images :: machine image commit sha guessed as {} using params: key: {}, group: {}, disk image revision: {}, bootstrap revision: {}'.format(machineImageCommitSha, key, group, diskImageRevision, bootstrapRevision))
            configTargetGroup = next((t for t in config['target'] if t['group'] == group), None)
            org = next((tag for tag in configTargetGroup['tag'] if tag['name'] == 'sourceOrganisation'), { 'value': '' })['value']
            repo = next((tag for tag in configTargetGroup['tag'] if tag['name'] == 'sourceRepository'), { 'value': '' })['value']
            print('tag-machine-images :: image: {}, has bootstrap revision: {} ({}/{})'.format(image.name, bootstrapRevision, org, repo))
            bootstrapCommit = get_commit(org, repo, bootstrapRevision)
            image.tags = {
                'deploymentId': bootstrapRevision,
                'diskImageCommitDate': diskImageCommit['commit']['committer']['date'][0:10],
                'diskImageCommitTime': diskImageCommit['commit']['committer']['date'],
                'diskImageCommitSha': diskImageCommit['sha'],
                'diskImageCommitMessage': diskImageCommit['commit']['message'].split('\n')[0],

                #'machineImageCommitDate': machineImageCommit['commit']['committer']['date'][0:10],
                #'machineImageCommitTime': machineImageCommit['commit']['committer']['date'],
                'machineImageCommitSha': machineImageCommitSha,
                #'machineImageCommitSha': machineImageCommit['sha'],
                #'machineImageCommitMessage': machineImageCommit['commit']['message'].split('\n')[0],

                'bootstrapCommitDate': bootstrapCommit['commit']['committer']['date'][0:10],
                'bootstrapCommitTime': bootstrapCommit['commit']['committer']['date'],
                'bootstrapCommitSha': bootstrapCommit['sha'],
                'bootstrapCommitMessage': bootstrapCommit['commit']['message'].split('\n')[0],
                'bootstrapCommitOrg': org,
                'bootstrapCommitRepo': repo,

                'isoName': os.path.basename(config['iso']['source']['key']),
                'isoIndex': config['iso']['wimindex'],
                'os': config['image']['os'],
                'edition': config['image']['edition'],
                'language': config['image']['language'],
                'architecture': config['image']['architecture']
            }
        else:
            print('tag-machine-images :: failed to guess machine image commit sha using params: key: {}, group: {}, disk image revision: {}, bootstrap revision: {}. using disk image tag subset only...'.format(key, group, diskImageRevision, bootstrapRevision))
            image.tags = {
                'diskImageCommitDate': diskImageCommit['commit']['committer']['date'][0:10],
                'diskImageCommitTime': diskImageCommit['commit']['committer']['date'],
                'diskImageCommitSha': diskImageCommit['sha'],
                'diskImageCommitMessage': diskImageCommit['commit']['message']
            }
        azureComputeManagementClient.images.create_or_update(group, image.name, image)
        print('tag-machine-images :: image tags updated')
        print(', '.join(['%s:: %s' % (k, v) for (k, v) in image.tags.items()]))

    snapshots = [x for x in azureComputeManagementClient.snapshots.list_by_resource_group(group) if pattern.match(x.name)]
    for snapshot in snapshots:
        diskImageRevision = pattern.search(snapshot.name).group(1)
        bootstrapRevision = pattern.search(snapshot.name).group(2)
        print('tag-machine-images :: snapshot: {}, has disk image revision: {} (mozilla-platform-ops/cloud-image-builder)'.format(snapshot.name, diskImageRevision))
        diskImageCommit = get_commit('mozilla-platform-ops', 'cloud-image-builder', diskImageRevision)
        if snapshot.tags:
            print('tag-machine-images :: snapshot has tags: {}'.format(', '.join(['%s:: %s' % (k, v) for (k, v) in snapshot.tags.items()])))
            print('tag-machine-images :: updating tags...')
        else:
            print('tag-machine-images :: snapshot has no tags. creating tags...')
        machineImageCommitSha, config = guess_config(key, group, diskImageRevision, bootstrapRevision)
        if config is not None:
            print('tag-machine-images :: machine image commit sha guessed as {} using params: key: {}, group: {}, disk image revision: {}, bootstrap revision: {}'.format(machineImageCommitSha, key, group, diskImageRevision, bootstrapRevision))
            configTargetGroup = next((t for t in config['target'] if t['group'] == group), None)
            org = next((tag for tag in configTargetGroup['tag'] if tag['name'] == 'sourceOrganisation'), { 'value': '' })['value']
            repo = next((tag for tag in configTargetGroup['tag'] if tag['name'] == 'sourceRepository'), { 'value': '' })['value']
            print('tag-machine-images :: snapshot: {}, has bootstrap revision: {} ({}/{})'.format(snapshot.name, bootstrapRevision, org, repo))
            bootstrapCommit = get_commit(org, repo, bootstrapRevision)
            snapshot.tags = {
                'deploymentId': bootstrapRevision,
                'diskImageCommitDate': diskImageCommit['commit']['committer']['date'][0:10],
                'diskImageCommitTime': diskImageCommit['commit']['committer']['date'],
                'diskImageCommitSha': diskImageCommit['sha'],
                'diskImageCommitMessage': diskImageCommit['commit']['message'].split('\n')[0],

                #'machineImageCommitDate': machineImageCommit['commit']['committer']['date'][0:10],
                #'machineImageCommitTime': machineImageCommit['commit']['committer']['date'],
                'machineImageCommitSha': machineImageCommitSha,
                #'machineImageCommitSha': machineImageCommit['sha'],
                #'machineImageCommitMessage': machineImageCommit['commit']['message'].split('\n')[0],

                'bootstrapCommitDate': bootstrapCommit['commit']['committer']['date'][0:10],
                'bootstrapCommitTime': bootstrapCommit['commit']['committer']['date'],
                'bootstrapCommitSha': bootstrapCommit['sha'],
                'bootstrapCommitMessage': bootstrapCommit['commit']['message'].split('\n')[0],
                'bootstrapCommitOrg': org,
                'bootstrapCommitRepo': repo,

                'isoName': os.path.basename(config['iso']['source']['key']),
                'isoIndex': config['iso']['wimindex'],
                'os': config['image']['os'],
                'edition': config['image']['edition'],
                'language': config['image']['language'],
                'architecture': config['image']['architecture']
            }
        else:
            print('tag-machine-images :: failed to guess machine image commit sha using params: key: {}, group: {}, disk image revision: {}, bootstrap revision: {}. using disk image tag subset only...'.format(key, group, diskImageRevision, bootstrapRevision))
            snapshot.tags = {
                'diskImageCommitDate': diskImageCommit['commit']['committer']['date'][0:10],
                'diskImageCommitTime': diskImageCommit['commit']['committer']['date'],
                'diskImageCommitSha': diskImageCommit['sha'],
                'diskImageCommitMessage': diskImageCommit['commit']['message']
            }
        azureComputeManagementClient.snapshots.create_or_update(group, snapshot.name, snapshot)
        print('tag-machine-images :: snapshot tags updated')
        print(', '.join(['%s:: %s' % (k, v) for (k, v) in snapshot.tags.items()]))
else:
    print('tag-machine-images :: skipped image and snapshot tagging. not implemented for platform: {}'.format(platform))