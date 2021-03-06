param (
  [Parameter(Mandatory = $true)]
  [ValidateSet('amazon', 'azure', 'google')]
  [string] $platform,

  [Parameter(Mandatory = $true)]
  [ValidateSet('win10-64-occ', 'win10-64', 'win10-64-gpu', 'win7-32', 'win7-32-gpu', 'win2012', 'win2019')]
  [string] $imageKey,

  [string] $group,
  [switch] $enableSnapshotCopy = $false,
  [switch] $overwrite = $false,

  [switch] $disableCleanup = $false
)

function Invoke-OptionalSleep {
  param (
    [string] $command,
    [string] $separator = ' ',
    [string] $action = $(
      if (($command.Split($separator).Length -gt 1) -and ($command.Split($separator)[1] -in @('in', 'after'))) {
        $command.Split($separator)[1]
      } else {
        $null
      }
    ),
    [int] $duration = $(
      if (($command.Split($separator).Length -gt 2) -and ($command.Split($separator)[2] -match "^\d+$")) {
        [int]$command.Split($separator)[2]
      } else {
        0
      }
    ),
    [string] $unit = $(
      if (($command.Split($separator).Length -gt 3) -and ($command.Split($separator)[3] -in @('millisecond', 'milliseconds', 'ms', 'second', 'seconds', 's', 'minute', 'minutes', 'm'))) {
        $command.Split($separator)[1]
      } else {
        'seconds'
      }
    )
  )
  begin {
    if ($action -and ($duration -gt 0)) {
      Write-Output -InputObject ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
    }
  }
  process {
    if ($action -and ($duration -gt 0)) {
      Write-Output -InputObject ('{0} :: sleeping for {1} {2}' -f $($MyInvocation.MyCommand.Name), $duration, $unit);
      switch -regex ($unit) {
        '^(millisecond|milliseconds|ms)$' {
          Start-Sleep -Milliseconds $duration;
        }
        '^(second|seconds|s)$' {
          Start-Sleep -Seconds $duration;
        }
        '^(minute|minutes|m)$' {
          Start-Sleep -Seconds ($duration * 60);
        }
      }
    }
  }
  end {
    if ($action -and ($duration -gt 0)) {
      Write-Output -InputObject ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
    }
  }
}

function Get-InstanceStatus {
  param (
    [string] $instanceName,
    [string] $groupName,
    [string] $errorAction
  )
  begin {
    Write-Debug -Message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    $lastStatus = $(if ($errorAction -eq 'SilentlyContinue') { @{ 'Code' = $null; 'Message' = $null; } } else { $null });
    try {
      $statuses = (Get-AzVm -Name $instanceName -ResourceGroupName $groupName -Status).Statuses;
      $lastStatus = $statuses[$statuses.Count - 1];
    } catch {
      $lastStatus = $(if ($errorAction -eq 'SilentlyContinue') { @{ 'Code' = $null; 'Message' = $null; } } else { $null });
    }
    return $lastStatus;
  }
  end {
    Write-Debug -Message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Invoke-BootstrapExecution {
  param (
    [int] $executionNumber,
    [int] $executionCount,
    [string] $instanceName,
    [string] $groupName,
    [object] $execution,
    [object] $flow,
    [string] $workFolder,
    [int] $attemptNumber = 1,
    [switch] $disableCleanup = $false
  )
  begin {
    Write-Output -InputObject ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    $instanceStatus = (Get-InstanceStatus -instanceName $instanceName -groupName $groupName);
    if (($instanceStatus) -and ($instanceStatus.Code -eq 'PowerState/running')) {
      Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7} has been invoked' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName);
      $tokenisedCommandEvaluationErrors = @();
      $runCommandScriptContent = [String]::Join('; ', @(
        $execution.commands | % {
          # tokenised commands (usually commands containing secrets), need to have each of their token values evaluated (eg: to perform a secret lookup)
          if ($_.format -and $_.tokens) {
            $tokenisedCommand = $_;
            try {
              ($tokenisedCommand.format -f @($tokenisedCommand.tokens | % { (Invoke-Expression -Command $_) } ))
            } catch {
              $tokenisedCommandEvaluationErrors += @{
                'format' = $tokenisedCommand.format;
                'tokens' = $tokenisedCommand.tokens;
                'exception' = $_.Exception
              };
            }
          } else {
            $_
          }
        }
      ));
      if ($tokenisedCommandEvaluationErrors.Length) {
        foreach ($tokenisedCommandEvaluationError in $tokenisedCommandEvaluationErrors) {
          Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}, threw exception evaluating tokenised command (format: "{8}", tokens: "{9}")' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName, $tokenisedCommandEvaluationError.format, [String]::Join(', ', $tokenisedCommandEvaluationError.tokens));
          Write-Output -InputObject ($tokenisedCommandEvaluationError.exception.Message);
        }
        if (-not $disableCleanup) {
          Remove-Resource -resourceId $instanceName.Replace('vm-', '') -resourceGroupName $groupName;
        }
        exit 1;
      }
      $runCommandScriptPath = ('{0}\{1}.ps1' -f $env:Temp, $execution.name);
      Set-Content -Path $runCommandScriptPath -Value $runCommandScriptContent;
      switch ($execution.shell) {
        'azure-powershell' {
          $runCommandResult = (Invoke-AzVMRunCommand `
            -ResourceGroupName $groupName `
            -VMName $instanceName `
            -CommandId 'RunPowerShellScript' `
            -ScriptPath $runCommandScriptPath);
          Remove-Item -Path $runCommandScriptPath;
          Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}, has status: {8}' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName, $(if (($runCommandResult) -and ($runCommandResult.Status)) { $runCommandResult.Status.ToLower() } else { '-' }));
          if (($runCommandResult.Value) -and ($runCommandResult.Value.Length -gt 0) -and ($runCommandResult.Value[0].Message)) {
            Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}, has std out:' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName);
            Write-Output -InputObject $runCommandResult.Value[0].Message;
          } else {
            Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}, did not produce output on std out stream' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName);
          }
          if (($runCommandResult.Value) -and ($runCommandResult.Value.Length -gt 1) -and ($runCommandResult.Value[1].Message)) {
            Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}, has std err:' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName);
            Write-Output -InputObject $runCommandResult.Value[1].Message;
          } else {
            Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}, did not produce output on std err stream' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName);
          }
          if (($runCommandResult.Value) -and ($runCommandResult.Value.Length -gt 0)) {
            if ($execution.test) {
              if ($execution.test.std) {
                if ($execution.test.std.out) {
                  if ($execution.test.std.out.match) {
                    if ($runCommandResult.Value[0].Message -match $execution.test.std.out.match) {
                      Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}, matched: "{8}" in std out' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName, $execution.test.std.out.match);
                      if ($execution.on.success) {
                        Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}, has triggered success action: {8}' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName, $execution.on.success);
                        switch ($execution.on.success.Split(' ')[0]) {
                          'reboot' {
                            Invoke-OptionalSleep -command $execution.on.success;
                            Restart-AzVM -ResourceGroupName $groupName -Name $instanceName;
                          }
                          default {
                            Write-Output -InputObject ('{0} :: no implementation found for std out regex match success action: {1}' -f $($MyInvocation.MyCommand.Name), $execution.on.success);
                          }
                        }
                      }
                    } else {
                      Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}, did not match: "{8}" in std out' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName, $execution.test.std.out.match);
                      if ($execution.on.failure) {
                        Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}, has triggered failure action: {8}' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName, $execution.on.failure);
                        switch ($execution.on.failure.Split(' ')[0]) {
                          'reboot' {
                            Invoke-OptionalSleep -command $execution.on.failure;
                            Restart-AzVM -ResourceGroupName $groupName -Name $instanceName;
                          }
                          'retry' {
                            Invoke-OptionalSleep -command $execution.on.failure;
                            Invoke-BootstrapExecution -executionNumber $executionNumber -executionCount $executionCount -instanceName $instanceName -groupName $groupName -execution $execution -attemptNumber ($attemptNumber + 1) -flow $flow -disableCleanup:$disableCleanup;
                          }
                          'retry-task' {
                            Invoke-OptionalSleep -command $execution.on.failure;
                            Remove-Resource -resourceId $instanceName.Replace('vm-', '') -resourceGroupName $groupName;
                            exit 123;
                          }
                          'fail' {
                            Invoke-OptionalSleep -command $execution.on.failure;
                            if (-not $disableCleanup) {
                              Remove-Resource -resourceId $instanceName.Replace('vm-', '') -resourceGroupName $groupName;
                            }
                            exit 1;
                          }
                          default {
                            Write-Output -InputObject (('{0} :: no implementation found for std out regex match failure action: {1}' -f $($MyInvocation.MyCommand.Name), $execution.on.failure));
                          }
                        }
                      }
                    }
                  }
                }
                if ($execution.test.std.err) {
                  Write-Output -InputObject (('{0} :: no implementation found for std err test action' -f $($MyInvocation.MyCommand.Name)));
                }
              }
              if ($execution.test.status) {
                if ($execution.test.status.code) {
                  if ($execution.test.status.code.match) {
                    if ((Get-InstanceStatus -instanceName $instanceName -groupName $groupName -ErrorAction 'SilentlyContinue').Code -match $execution.test.status.code.match) {
                      Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}, matched: "{8}" in instance status code' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName, $execution.test.std.out.match);
                    } else {
                      Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}, did not match: "{8}" in instance status code' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName, $execution.test.std.out.match);
                      # todo: implement results other than 'failure'
                      if ($execution.on.failure) {
                        Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}, has triggered failure action: {8}' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName, $execution.on.failure);
                        switch ($execution.on.failure.Split(' ')[0]) {
                          # todo: implement actions other than 'retest'
                          'retest' {
                            while ((Get-InstanceStatus -instanceName $instanceName -groupName $groupName -ErrorAction 'SilentlyContinue').Code -notmatch $execution.test.status.code.match) {
                              Invoke-OptionalSleep -command $execution.on.failure;
                            }
                          }
                          default {
                            Write-Output -InputObject (('{0} :: no implementation found for std out regex match failure action: {1}' -f $($MyInvocation.MyCommand.Name), $execution.on.failure));
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          } else {
            $instanceStatus = (Get-InstanceStatus -instanceName $instanceName -groupName $groupName);
            if (($instanceStatus) -and ($instanceStatus.Code -eq 'PowerState/stopped')) {
              Write-Output -InputObject ('{0} :: instance shutdown detected during bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName);
            } elseif (($instanceStatus) -and ($instanceStatus.Code -eq 'PowerState/running')) {
              Write-Output -InputObject ('{0} :: running instance state ({1}) detected during bootstrap execution {2}/{3}, attempt {4}; {5}, using shell: {6}, on: {7}/{8}' -f $($MyInvocation.MyCommand.Name), $instanceStatus.Code, $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName);
              Publish-Screenshot -instanceName $instanceName -groupName $groupName -platform 'azure' -workFolder $workFolder;
            } elseif ($instanceStatus) {
              Write-Output -InputObject ('{0} :: unhandled instance state {1} detected during bootstrap execution {2}/{3}, attempt {4}; {5}, using shell: {6}, on: {7}/{8}' -f $($MyInvocation.MyCommand.Name), $instanceStatus.Code, $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName);
            } else {
              Write-Output -InputObject ('{0} :: missing instance state detected during bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7}' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName);
            }
          }
        }
        # bootstrap over winrm for architectures that do not have an azure vm agent
        'winrm-powershell' {
          $publicIpAddress = (Get-PublicIpAddress -platform $platform -group $groupName -resourceId $resourceId);
          if (-not ($publicIpAddress)) {
            Write-Output -InputObject ('{0} :: failed to determine public ip address for resource: {1}, in group: {2}, on platform: {3}' -f $($MyInvocation.MyCommand.Name), $resourceId, $groupName, $platform);
            exit 1;
          } else {
            Write-Output -InputObject ('{0} :: public ip address: {1}, found for resource: {2}, in group: {3}, on platform: {4}' -f $($MyInvocation.MyCommand.Name), $publicIpAddress, $resourceId, $groupName, $platform);
          }
          $adminPassword = (Get-AdminPassword -platform $platform -imageKey $imageKey);
          if (-not ($adminPassword)) {
            Write-Output -InputObject ('{0} :: failed to determine admin password for image: {1}, on platform: {2}, using: {3}/api/index/v1/task/project.relops.cloud-image-builder.{2}.{1}.latest/artifacts/public/unattend.xml' -f $($MyInvocation.MyCommand.Name), $imageKey, $platform, $env:TASKCLUSTER_ROOT_URL);
            exit 1;
          } else {
            Write-Output -InputObject ('{0} :: admin password for image: {1}, on platform: {2}, found at: {3}/api/index/v1/task/project.relops.cloud-image-builder.{2}.{1}.latest/artifacts/public/unattend.xml' -f $($MyInvocation.MyCommand.Name), $imageKey, $platform, $env:TASKCLUSTER_ROOT_URL);
          }
          $credential = (New-Object `
            -TypeName 'System.Management.Automation.PSCredential' `
            -ArgumentList @('.\Administrator', (ConvertTo-SecureString $adminPassword -AsPlainText -Force)));

          # modify security group of remote azure instance to allow winrm from public ip of local task instance
          try {
            $taskRunnerIpAddress = (New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/public-ipv4');
            $azNetworkSecurityGroup = (Get-AzNetworkSecurityGroup -Name $flow.name);
            $winrmAzNetworkSecurityRuleConfig = (Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $azNetworkSecurityGroup -Name 'allow-winrm' -ErrorAction SilentlyContinue);
            if ($winrmAzNetworkSecurityRuleConfig) {
              $setAzNetworkSecurityRuleConfigResult = (Set-AzNetworkSecurityRuleConfig `
                -Name 'allow-winrm' `
                -NetworkSecurityGroup $azNetworkSecurityGroup `
                -SourceAddressPrefix @(@($taskRunnerIpAddress) + $winrmAzNetworkSecurityRuleConfig.SourceAddressPrefix));
            } else {
              $winrmRuleFromConfig = @($flow.rules | ? { $_.name -eq 'allow-winrm' })[0];
              $setAzNetworkSecurityRuleConfigResult = (Add-AzNetworkSecurityRuleConfig `
                -Name $winrmRuleFromConfig.name `
                -Description $winrmRuleFromConfig.Description `
                -Access $winrmRuleFromConfig.Access `
                -Protocol $winrmRuleFromConfig.Protocol `
                -Direction $winrmRuleFromConfig.Direction `
                -Priority $winrmRuleFromConfig.Priority `
                -SourceAddressPrefix @(@($taskRunnerIpAddress) + $winrmRuleFromConfig.SourceAddressPrefix) `
                -SourcePortRange $winrmRuleFromConfig.SourcePortRange `
                -DestinationAddressPrefix $winrmRuleFromConfig.DestinationAddressPrefix `
                -DestinationPortRange $winrmRuleFromConfig.DestinationPortRange);
            }
            if ($setAzNetworkSecurityRuleConfigResult.ProvisioningState -eq 'Succeeded') {
              $updatedIps = @($setAzNetworkSecurityRuleConfigResult.SecurityRules | ? { $_.Name -eq 'allow-winrm' })[0].SourceAddressPrefix;
              Write-Output -InputObject ('winrm firewall configuration at: {0}/allow-winrm, modified to allow inbound from: {1}' -f $flow.name, [String]::Join(', ', $updatedIps));
            } else {
              Write-Output -InputObject ('error: failed to modify winrm firewall configuration. provisioning state: {0}' -f $setAzNetworkSecurityRuleConfigResult.ProvisioningState);
              exit 1;
            }
          } catch {
            Write-Output -InputObject ('error: failed to modify winrm firewall configuration. {0}' -f $_.Exception.Message);
            exit 1;
          }

          # enable remoting and add remote azure instance to trusted host list
          try {
            #Enable-PSRemoting -SkipNetworkProfileCheck -Force
            #Write-Output -InputObject 'powershell remoting enabled for session';

            & winrm @('set', 'winrm/config/client', '@{AllowUnencrypted="true"}');
            Write-Output -InputObject 'winrm-client allow-unencrypted set to: "true"';

            $trustedHostsPreBootstrap = (Get-Item -Path 'WSMan:\localhost\Client\TrustedHosts').Value;
            Write-Output -InputObject ('winrm-client trusted-hosts detected as: "{0}"' -f $trustedHostsPreBootstrap);
            $trustedHostsForBootstrap = $(if (($trustedHostsPreBootstrap) -and ($trustedHostsPreBootstrap.Length -gt 0)) { ('{0},{1}' -f $trustedHostsPreBootstrap, $publicIpAddress) } else { $publicIpAddress });
            #Set-Item -Path 'WSMan:\localhost\Client\TrustedHosts' -Value $trustedHostsForBootstrap -Force;
            & winrm @('set', 'winrm/config/client', ('@{{TrustedHosts="{0}"}}' -f $trustedHostsForBootstrap));
            Write-Output -InputObject ('winrm-client trusted-hosts set to: "{0}"' -f (Get-Item -Path 'WSMan:\localhost\Client\TrustedHosts').Value);
          } catch {
            Write-Output -InputObject ('error: failed to modify winrm firewall configuration. {0}' -f $_.Exception.Message);
            exit 1;
          }
          $invocationResponse = $null;
          $invocationAttempt = 0;
          $statuses = (Get-AzVm -Name $instanceName -ResourceGroupName $groupName -Status).Statuses;
          $lastStatus = $statuses[$statuses.Count - 1];
          do {
            $invocationAttempt += 1;
            # run remote bootstrap scripts over winrm
            try {
              $invocationResponse = (Invoke-Command `
                -ComputerName $publicIpAddress `
                -Credential $credential `
                -ScriptBlock { $runCommandScriptContent });
            } catch {
              Write-Output -InputObject ('error: failed to execute bootstrap commands over winrm on attempt {0}. {1}' -f $invocationAttempt, $_.Exception.Message);
              exit 1;
            } finally {
              if ($invocationResponse) {
                Write-Output -InputObject $invocationResponse;
                if ($invocationResponse -match 'WinRMOperationTimeout') {
                  Write-Output -InputObject 'awaiting manual intervention to correct the winrm connection issue';
                  Start-Sleep -Seconds 120
                }
              } else {
                Write-Output -InputObject ('error: no response received during execution of bootstrap commands over winrm on attempt {0}' -f $invocationAttempt);
              }
            }
            $statuses = (Get-AzVm -Name $instanceName -ResourceGroupName $groupName -Status).Statuses;
            $lastStatus = $statuses[$statuses.Count - 1];
            Write-Output -InputObject ('{0}/{1} has {2} status tags and last status: {3} ({4})' -f $groupName, $instanceName, $statuses.Count, $lastStatus.DisplayStatus, $lastStatus.Code);
          } while (
            (
              ($lastStatus.Code -ne 'PowerState/stopped') -and
              ($lastStatus.Code -ne 'PowerState/deallocated')
            ) -and (
              # repeat the winrm invocation until it works or the task exceeds its timeout, allowing for manual
              # intervention on the host instance to enable the winrm connection or connection issue debugging.
              ($invocationResponse -eq $null) -or
              ($invocationResponse -match 'WinRMOperationTimeout')
            )
          )
          # modify azure security group to remove public ip of task instance from winrm exceptions
          $allowedIps = @($flow.rules | ? { $_.name -eq 'allow-winrm' })[0].sourceAddressPrefix
          $setAzNetworkSecurityRuleConfigResult = (Set-AzNetworkSecurityRuleConfig `
            -Name 'allow-winrm' `
            -NetworkSecurityGroup $azNetworkSecurityGroup `
            -SourceAddressPrefix $allowedIps);
          if ($setAzNetworkSecurityRuleConfigResult.ProvisioningState -eq 'Succeeded') {
            $updatedIps = @($setAzNetworkSecurityRuleConfigResult.SecurityRules | ? { $_.Name -eq 'allow-winrm' })[0].SourceAddressPrefix;
            Write-Output -InputObject ('winrm firewall configuration at: {0}/allow-winrm, reverted to allow inbound from: {1}' -f $flow.name, [String]::Join(', ', $updatedIps));
          } else {
            Write-Output -InputObject ('error: failed to revert winrm firewall configuration. provisioning state: {0}' -f $setAzNetworkSecurityRuleConfigResult.ProvisioningState);
          }

          #Set-Item -Path 'WSMan:\localhost\Client\TrustedHosts' -Value $(if (($trustedHostsPreBootstrap) -and ($trustedHostsPreBootstrap.Length -gt 0)) { $trustedHostsPreBootstrap } else { '' }) -Force;
          & winrm @('set', 'winrm/config/client', ('@{{TrustedHosts="{0}"}}' -f $trustedHostsPreBootstrap));
          Write-Output -InputObject ('winrm-client trusted-hosts reverted to: "{0}"' -f (Get-Item -Path 'WSMan:\localhost\Client\TrustedHosts').Value);
          & winrm @('set', 'winrm/config/client', '@{AllowUnencrypted="false"}');
          Write-Output -InputObject 'winrm-client allow-unencrypted reverted to: "false"';
        }
      }
      Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7} has been completed' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName);
    } else {
      Write-Output -InputObject ('{0} :: bootstrap execution {1}/{2}, attempt {3}; {4}, using shell: {5}, on: {6}/{7} has been skipped. instance is not running.' -f $($MyInvocation.MyCommand.Name), $executionNumber, $executionCount, $attemptNumber, $execution.name, $execution.shell, $groupName, $instanceName);
    }
  }
  end {
    Write-Output -InputObject ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Invoke-BootstrapExecutions {
  param (
    [string] $instanceName,
    [string] $groupName,
    [object[]] $executions,
    [object] $flow,
    [switch] $disableCleanup = $false
  )
  begin {
    Write-Output -InputObject ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    if ($executions -and $executions.Length) {
      $executionNumber = 1;
      Write-Output -InputObject ('{0} :: detected {1} bootstrap command execution configurations for: {2}/{3}' -f $($MyInvocation.MyCommand.Name), $executions.Length, $groupName, $instanceName);
      foreach ($execution in $executions) {
        Invoke-BootstrapExecution -executionNumber $executionNumber -executionCount $executions.Length -instanceName $instanceName -groupName $groupName -execution $execution -flow $flow -disableCleanup:$disableCleanup;
        $executionNumber += 1;
      }
    }
  }
  end {
    Write-Output -InputObject ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Remove-Resource {
  param (
    [string] $resourceId,
    [string] $resourceGroupName,
    [string[]] $resourceNames = @(
      ('cib-{0}' -f $resourceId),
      ('vm-{0}' -f $resourceId),
      ('ni-{0}' -f $resourceId),
      ('ip-{0}' -f $resourceId),
      ('disk-{0}*' -f $resourceId)
    )
  )
  begin {
    Write-Output -InputObject ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    # instance instantiation failures leave behind a disk, public ip and network interface which need to be deleted.
    # the deletion will fail if the failed instance deletion is not complete.
    # retry for a while before giving up.
    do {
      foreach ($resourceName in $resourceNames) {
        $resourceType = @{
          'cib' = 'virtual machine';
          'vm' = 'virtual machine';
          'ni' = 'network interface';
          'ip' = 'public ip address';
          'disk' = 'disk'
        }[$resourceName.Split('-')[0]];
        switch ($resourceType) {
          'virtual machine' {
            if (Get-AzVM -ResourceGroupName $resourceGroupName -Name $resourceName -ErrorAction SilentlyContinue) {
              try {
                $operation = (Remove-AzVm `
                  -ResourceGroupName $resourceGroupName `
                  -Name $resourceName `
                  -Force `
                  -ErrorAction SilentlyContinue);
                if ($operation.Status -eq 'Succeeded') {
                  Write-Output -InputObject (('{0} :: {1}: {2}/{3}, removal appears successful' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $resourceName));
                } else {
                  Write-Output -InputObject (('{0} :: {1}: {2}/{3}, removal failed with status: {4}. {5}' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $resourceName, $operation.Status, $operation.Error));
                }
              } catch {
                Write-Output -InputObject (('{0} :: {1}: {2}/{3}, removal threw exception. {4}' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $resourceName, $_.Exception.Message));
              }
            } else {
              Write-Output -InputObject (('{0} :: {1}: {2}/{3} not found. removal skipped' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $resourceName));
            }
          }
          'network interface' {
            if (Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $resourceName -ErrorAction SilentlyContinue) {
              try {
                $operation = (Remove-AzNetworkInterface `
                  -ResourceGroupName $resourceGroupName `
                  -Name $resourceName `
                  -Force `
                  -ErrorAction SilentlyContinue);
                if ($operation.Status -eq 'Succeeded') {
                  Write-Output -InputObject (('{0} :: {1}: {2}/{3}, removal appears successful' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $resourceName));
                } else {
                  Write-Output -InputObject (('{0} :: {1}: {2}/{3}, removal failed with status: {4}. {5}' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $resourceName, $operation.Status, $operation.Error));
                }
              } catch {
                Write-Output -InputObject (('{0} :: {1}: {2}/{3}, removal threw exception. {4}' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $resourceName, $_.Exception.Message));
              }
            } else {
              Write-Output -InputObject (('{0} :: {1}: {2}/{3} not found. removal skipped' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $resourceName));
            }
          }
          'public ip address' {
            if (Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $resourceName -ErrorAction SilentlyContinue) {
              try {
                $operation = (Remove-AzPublicIpAddress `
                  -ResourceGroupName $resourceGroupName `
                  -Name $resourceName `
                  -Force `
                  -ErrorAction SilentlyContinue);
                if ($operation.Status -eq 'Succeeded') {
                  Write-Output -InputObject (('{0} :: {1}: {2}/{3}, removal appears successful' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $resourceName));
                } else {
                  Write-Output -InputObject (('{0} :: {1}: {2}/{3}, removal failed with status: {4}. {5}' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $resourceName, $operation.Status, $operation.Error));
                }
              } catch {
                Write-Output -InputObject (('{0} :: {1}: {2}/{3}, removal threw exception. {4}' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $resourceName, $_.Exception.Message));
              }
            } else {
              Write-Output -InputObject (('{0} :: {1}: {2}/{3} not found. removal skipped' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $resourceName));
            }
          }
          'disk' {
            if (Get-AzDisk -ResourceGroupName $resourceGroupName -DiskName $resourceName -ErrorAction SilentlyContinue) {
              foreach ($azDisk in @(Get-AzDisk -ResourceGroupName $resourceGroupName -DiskName $resourceName -ErrorAction SilentlyContinue)) {
                try {
                  $operation = (Remove-AzDisk `
                    -ResourceGroupName $resourceGroupName `
                    -DiskName $azDisk.Name `
                    -Force `
                    -ErrorAction SilentlyContinue);
                  if ($operation.Status -eq 'Succeeded') {
                    Write-Output -InputObject (('{0} :: {1}: {2}/{3}, removal appears successful' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $azDisk.Name));
                  } else {
                    Write-Output -InputObject (('{0} :: {1}: {2}/{3}, removal failed with status: {4}. {5}' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $azDisk.Name, $operation.Status, $operation.Error));
                  }
                } catch {
                  Write-Output -InputObject (('{0} :: {1}: {2}/{3}, removal threw exception. {4}' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $azDisk.Name, $_.Exception.Message));
                }
              }
            } else {
              Write-Output -InputObject (('{0} :: {1}: {2}/{3} not found. removal skipped' -f $($MyInvocation.MyCommand.Name), $resourceType, $resourceGroupName, $resourceName));
            }
          }
        }
      }
    } while (
      (Get-AzVM -ResourceGroupName $resourceGroupName -Name ('vm-{0}' -f $resourceId) -ErrorAction SilentlyContinue) -or
      (Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name ('ni-{0}' -f $resourceId) -ErrorAction SilentlyContinue) -or
      (Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name ('ip-{0}' -f $resourceId) -ErrorAction SilentlyContinue) -or
      (Get-AzDisk -ResourceGroupName $resourceGroupName -DiskName ('disk-{0}*' -f $resourceId) -ErrorAction SilentlyContinue)
    )
  }
  end {
    Write-Output -InputObject ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Update-RequiredModules {
  param (
    [string] $repository = 'PSGallery',
    [hashtable[]] $requiredModules = @(
      @{
        'module' = 'Az.Compute';
        'version' = '3.1.0'
      },
      @{
        'module' = 'Az.Network';
        'version' = '2.1.0'
      },
      @{
        'module' = 'Az.Resources';
        'version' = '1.8.0'
      },
      @{
        'module' = 'Az.Storage';
        'version' = '1.9.0'
      },
      @{
        'module' = 'posh-minions-managed';
        'version' = '0.0.114'
      },
      @{
        'module' = 'powershell-yaml';
        'version' = '0.4.1'
      }
    )
  )
  begin {
    Write-Output -InputObject ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
    Write-Output -InputObject ('{0} :: installed module version observations (before updates):' -f $($MyInvocation.MyCommand.Name));
    foreach ($m in (Get-Module)) {
      Write-Output -InputObject ('{0} :: {1} - {2}' -f $($MyInvocation.MyCommand.Name), $m.Name, $m.Version);
    }
  }
  process {
    if (@(Get-PSRepository -Name $repository)[0].InstallationPolicy -ne 'Trusted') {
      try {
        Set-PSRepository -Name $repository -InstallationPolicy 'Trusted';
        Write-Output -InputObject ('{0} :: setting of installation policy to trusted for repository: {1}, succeeded' -f $($MyInvocation.MyCommand.Name), $repository);
      } catch {
        Write-Output -InputObject ('{0} :: setting of installation policy to trusted for repository: {1}, failed. {2}' -f $($MyInvocation.MyCommand.Name), $repository, $_.Exception.Message);
      }
    }
    foreach ($rm in $requiredModules) {
      $module = (Get-Module -Name $rm.module -ErrorAction SilentlyContinue);
      if ($module) {
        if ($module.Version -lt $rm.version) {
          try {
            Update-Module -Name $rm.module -RequiredVersion $rm.version;
            Write-Output -InputObject ('{0} :: update of required module: {1}, version: {2}, succeeded' -f $($MyInvocation.MyCommand.Name), $rm.module, $rm.version);
          } catch {
            Write-Output -InputObject ('{0} :: update of required module: {1}, version: {2}, failed. {3}' -f $($MyInvocation.MyCommand.Name), $rm.module, $rm.version, $_.Exception.Message);
          }
        }
      } else {
        try {
          Install-Module -Name $rm.module -RequiredVersion $rm.version -AllowClobber;
          Write-Output -InputObject ('{0} :: install of required module: {1}, version: {2}, succeeded' -f $($MyInvocation.MyCommand.Name), $rm.module, $rm.version);
        } catch {
          Write-Output -InputObject ('{0} :: install of required module: {1}, version: {2}, failed. {3}' -f $($MyInvocation.MyCommand.Name), $rm.module, $rm.version, $_.Exception.Message);
        }
      }
      try {
        Import-Module -Name $rm.module -RequiredVersion $rm.version -ErrorAction SilentlyContinue;
        Write-Output -InputObject ('{0} :: import of required module: {1}, version: {2}, succeeded' -f $($MyInvocation.MyCommand.Name), $rm.module, $rm.version);
      } catch {
        Write-Output -InputObject ('{0} :: import of required module: {1}, version: {2}, failed. {3}' -f $($MyInvocation.MyCommand.Name), $rm.module, $rm.version, $_.Exception.Message);
        # if we get here, the instance is borked and will throw exceptions on all subsequent tasks.
        & shutdown @('/s', '/t', '3', '/c', 'borked powershell module library detected', '/f', '/d', '1:1');
        exit 123;
      }
    }
  }
  end {
    Write-Output -InputObject ('{0} :: installed module version observations (after updates):' -f $($MyInvocation.MyCommand.Name));
    foreach ($m in (Get-Module)) {
      Write-Output -InputObject ('{0} :: {1} - {2}' -f $($MyInvocation.MyCommand.Name), $m.Name, $m.Version);
    }
    Write-Output -InputObject ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Initialize-Platform {
  param (
    [string] $platform,
    [object] $secret
  )
  begin {
    Write-Output -InputObject ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    switch ($platform) {
      'azure' {
        try {
          Connect-AzAccount `
            -ServicePrincipal `
            -Credential (New-Object System.Management.Automation.PSCredential($secret.azure.id, (ConvertTo-SecureString `
              -String $secret.azure.key `
              -AsPlainText `
              -Force))) `
            -Tenant $secret.azure.account | Out-Null;
          Write-Output -InputObject ('{0} :: for platform: {1}, setting of credentials, succeeded' -f $($MyInvocation.MyCommand.Name), $platform);
        } catch {
          Write-Output -InputObject ('{0} :: for platform: {1}, setting of credentials, failed. {2}' -f $($MyInvocation.MyCommand.Name), $platform, $_.Exception.Message);
        }
        try {
          $azcopyExePath = ('{0}\azcopy.exe' -f $workFolder);
          $azcopyZipPath = ('{0}\azcopy.zip' -f $workFolder);
          $azcopyZipUrl = 'https://aka.ms/downloadazcopy-v10-windows';
          if (-not (Test-Path -Path $azcopyExePath -ErrorAction SilentlyContinue)) {
            (New-Object Net.WebClient).DownloadFile($azcopyZipUrl, $azcopyZipPath);
            if (Test-Path -Path $azcopyZipPath -ErrorAction SilentlyContinue) {
              Write-Output -InputObject ('{0} :: downloaded: {1} from: {2}' -f $($MyInvocation.MyCommand.Name), $azcopyZipPath, $azcopyZipUrl);
              Expand-Archive -Path $azcopyZipPath -DestinationPath $workFolder;
              try {
                $extractedAzcopyExePath = (@(Get-ChildItem -Path ('{0}\azcopy.exe' -f $workFolder) -Recurse -ErrorAction SilentlyContinue -Force)[0].FullName);
                Write-Output -InputObject ('{0} :: extracted: {1} from: {2}' -f $($MyInvocation.MyCommand.Name), $extractedAzcopyExePath, $azcopyZipPath);
                Copy-Item -Path $extractedAzcopyExePath -Destination $azcopyExePath;
                if (Test-Path -Path $azcopyExePath -ErrorAction SilentlyContinue) {
                  Write-Output -InputObject ('{0} :: copied: {1} to: {2}' -f $($MyInvocation.MyCommand.Name), $extractedAzcopyExePath, $azcopyExePath);
                  $env:PATH = ('{0};{1}' -f $env:PATH, $workFolder);
                  [Environment]::SetEnvironmentVariable('PATH', $env:PATH, 'User');
                  Write-Output -InputObject ('{0} :: user env PATH set to: {1}' -f $($MyInvocation.MyCommand.Name), $env:PATH);
                }
              } catch {
                Write-Output -InputObject ('{0} :: failed to extract azcopy from: {1}' -f $($MyInvocation.MyCommand.Name), $azcopyZipPath);
              }
            } else {
              Write-Output -InputObject ('{0} :: failed to download: {1} from: {2}' -f $($MyInvocation.MyCommand.Name), $azcopyZipPath, $azcopyZipUrl);
              exit 123;
            }
          }
          Write-Output -InputObject ('{0} :: for platform: {1}, acquire of platform tools, succeeded' -f $($MyInvocation.MyCommand.Name), $platform);
        } catch {
          Write-Output -InputObject ('{0} :: for platform: {1}, acquire of platform tools, failed. {2}' -f $($MyInvocation.MyCommand.Name), $platform, $_.Exception.Message);
        }
      }
      'amazon' {
        try {
          Set-AWSCredential `
            -AccessKey $secret.amazon.id `
            -SecretKey $secret.amazon.key `
            -StoreAs 'default' | Out-Null;
          Write-Output -InputObject ('{0} :: on platform: {1}, setting of credentials, succeeded' -f $($MyInvocation.MyCommand.Name), $platform);
        } catch {
          Write-Output -InputObject ('{0} :: on platform: {1}, setting of credentials, failed. {2}' -f $($MyInvocation.MyCommand.Name), $platform, $_.Exception.Message);
        }
      }
    }
  }
  end {
    Write-Output -InputObject ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Get-ImageArtifactDescriptor {
  param (
    [string] $platform,
    [string] $imageKey,
    [string] $uri = ('{0}/api/index/v1/task/project.relops.cloud-image-builder.{1}.{2}.latest/artifacts/public/image-bucket-resource.json' -f $env:TASKCLUSTER_ROOT_URL, $platform, $imageKey)
  )
  begin {
    Write-Debug -Message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    $imageArtifactDescriptor = $null;
    try {
      $memoryStream = (New-Object System.IO.MemoryStream(, (New-Object System.Net.WebClient).DownloadData($uri)));
      $streamReader = (New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode] 'Decompress')));
      $imageArtifactDescriptor = ($streamReader.ReadToEnd() | ConvertFrom-Json);
      Write-Debug -Message ('{0} :: disk image config for: {1}, on {2}, fetch and extraction from: {3}, suceeded' -f $($MyInvocation.MyCommand.Name), $imageKey, $platform, $uri);
    } catch {
      Write-Output -Message ('{0} :: disk image config for: {1}, on {2}, fetch and extraction from: {3}, failed. {4}' -f $($MyInvocation.MyCommand.Name), $imageKey, $platform, $uri, $_.Exception.Message);
      exit 1
    }
    return $imageArtifactDescriptor;
  }
  end {
    Write-Debug -Message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Invoke-SnapshotCopy {
  param (
    [string] $platform,
    [string] $imageKey,
    [object] $target,
    [string] $targetImageName,
    [object] $imageArtifactDescriptor,
    [string] $targetSnapshotName = ('{0}-{1}-{2}' -f $target.group.Replace('rg-', ''), $imageKey, $imageArtifactDescriptor.build.revision.Substring(0, 7))
  )
  begin {
    Write-Output -InputObject ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    # check if the image snapshot exists in another regional resource-group
    foreach ($source in @($config.target | ? { (($_.platform -eq $platform) -and $_.group -ne $group) })) {
      $sourceSnapshotName = ('{0}-{1}-{2}' -f $source.group.Replace('rg-', ''), $imageKey, $imageArtifactDescriptor.build.revision.Substring(0, 7));
      $sourceSnapshot = (Get-AzSnapshot `
        -ResourceGroupName $source.group `
        -SnapshotName $sourceSnapshotName `
        -ErrorAction SilentlyContinue);
      if ($sourceSnapshot) {
        Write-Output -InputObject ('{0} :: found snapshot: {1}, in group: {2}, in cloud platform: {3}. triggering machine copy from {2} to {4}...' -f $($MyInvocation.MyCommand.Name), $sourceSnapshotName, $source.group, $source.platform, $target.group);

        # get/create storage account in target region
        $storageAccountName = ('{0}cib' -f $target.group.Replace('rg-', '').Replace('-', ''));
        $targetAzStorageAccount = (Get-AzStorageAccount `
          -ResourceGroupName $target.group `
          -Name $storageAccountName);
        if ($targetAzStorageAccount) {
          Write-Output -InputObject ('{0} :: detected storage account: {1}, for resource group: {2}' -f $($MyInvocation.MyCommand.Name), $storageAccountName, $target.group);
        } else {
          $targetAzStorageAccount = (New-AzStorageAccount `
            -ResourceGroupName $target.group `
            -AccountName $storageAccountName `
            -Location $target.region.Replace(' ', '').ToLower() `
            -SkuName 'Standard_LRS');
          Write-Output -InputObject ('{0} :: created storage account: {1}, for resource group: {2}' -f $($MyInvocation.MyCommand.Name), $storageAccountName, $target.group);
        }
        if (-not ($targetAzStorageAccount)) {
          Write-Output -InputObject ('{0} :: failed to get or create az storage account: {1}' -f $($MyInvocation.MyCommand.Name), $storageAccountName);
          exit 1;
        }

        # get/create storage container (bucket) in target region
        $storageContainerName = ('{0}cib' -f $target.group.Replace('rg-', '').Replace('-', ''));
        $targetAzStorageContainer = (Get-AzStorageContainer `
          -Name $storageContainerName `
          -Context $targetAzStorageAccount.Context);
        if ($targetAzStorageContainer) {
          Write-Output -InputObject ('{0} :: detected storage container: {1}' -f $($MyInvocation.MyCommand.Name), $storageContainerName);
        } else {
          $targetAzStorageContainer = (New-AzStorageContainer `
            -Name $storageContainerName `
            -Context $targetAzStorageAccount.Context `
            -Permission 'Container');
          Write-Output -InputObject ('{0} :: created storage container: {1}' -f $($MyInvocation.MyCommand.Name), $storageContainerName);
        }
        if (-not ($targetAzStorageContainer)) {
          Write-Output -InputObject ('{0} :: failed to get or create az storage container: {1}' -f $($MyInvocation.MyCommand.Name), $storageContainerName);
          exit 1;
        }
         
        # copy snapshot to target container (bucket)
        $sourceAzSnapshotAccess = (Grant-AzSnapshotAccess `
          -ResourceGroupName $source.group `
          -SnapshotName $sourceSnapshotName `
          -DurationInSecond 3600 `
          -Access 'Read');
        Start-AzStorageBlobCopy `
          -AbsoluteUri $sourceAzSnapshotAccess.AccessSAS `
          -DestContainer $storageContainerName `
          -DestContext $targetAzStorageAccount.Context `
          -DestBlob $targetSnapshotName;
        # todo: wrap above cmdlet in try/catch and handle exceptions
        $targetAzStorageBlobCopyState = (Get-AzStorageBlobCopyState `
          -Container $storageContainerName `
          -Blob $targetSnapshotName `
          -Context $targetAzStorageAccount.Context `
          -WaitForComplete);
        $targetAzSnapshotConfig = (New-AzSnapshotConfig `
          -AccountType 'Standard_LRS' `
          -OsType 'Windows' `
          -Location $target.region.Replace(' ', '').ToLower() `
          -CreateOption 'Import' `
          -SourceUri ('{0}{1}/{2}' -f $targetAzStorageAccount.Context.BlobEndPoint, $storageContainerName, $targetSnapshotName) `
          -StorageAccountId $targetAzStorageAccount.Id);
        $targetAzSnapshot = (New-AzSnapshot `
          -ResourceGroupName $target.group `
          -SnapshotName $targetSnapshotName `
          -Snapshot $targetAzSnapshotConfig);
        Write-Output -InputObject ('{0} :: provisioning of snapshot: {1}, has state: {2}' -f $($MyInvocation.MyCommand.Name), $targetSnapshotName, $targetAzSnapshot.ProvisioningState.ToLower());
        $targetAzImageConfig = (New-AzImageConfig `
          -Location $target.region.Replace(' ', '').ToLower());
        $targetAzImageConfig = (Set-AzImageOsDisk `
          -Image $targetAzImageConfig `
          -OsType 'Windows' `
          -OsState 'Generalized' `
          -SnapshotId $targetAzSnapshot.Id);
        $targetAzImage = (New-AzImage `
          -ResourceGroupName $target.group `
          -ImageName $targetImageName `
          -Image $targetAzImageConfig);
        if (-not $targetAzImage) {
          Write-Output -InputObject ('{0} :: provisioning of image: {1}, failed' -f $($MyInvocation.MyCommand.Name), $targetImageName);
          exit 1;
        }
        Write-Output -InputObject ('{0} :: provisioning of image: {1}, has state: {2}' -f $($MyInvocation.MyCommand.Name), $targetImageName, $targetAzImage.ProvisioningState.ToLower());
        exit;
      }
    }
  }
  end {
    Write-Output -InputObject ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Get-AzureSkuFamily {
  param (
    [string] $sku
  )
  begin {
    Write-Debug -Message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    switch -regex ($sku) {
      '^Basic_A[0-9]+$' {
        $skuFamily = 'Basic A Family vCPUs';
        break;
      }
      '^Standard_A[0-7]$' {
        $skuFamily = 'Standard A0-A7 Family vCPUs';
        break;
      }
      '^Standard_A(8|9|10|11)$' {
        $skuFamily = 'Standard A8-A11 Family vCPUs';
        break;
      }
      '^(Basic|Standard)_(B|D|E|F|H|L|M)[0-9]+m?r?$' {
        $skuFamily = '{0} {1} Family vCPUs' -f $matches[1], $matches[2];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)[0-9]+m?r?_Promo$' {
        $skuFamily = '{0} {1} Promo Family vCPUs' -f $matches[1], $matches[2];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)[0-9]+[lmt]?s$' {
        $skuFamily = '{0} {1}S Family vCPUs' -f $matches[1], $matches[2];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M|P)([BC])[0-9]+r?s$' {
        $skuFamily = '{0} {1}{2}S Family vCPUs' -f $matches[1], $matches[2], $matches[3];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)[0-9]+(-(1|2|4|8|16|32|64))?m?s$' {
        $skuFamily = '{0} {1}S Family vCPUs' -f $matches[1], $matches[2];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)S[0-9]+$' {
        $skuFamily = '{0} {1}S Family vCPUs' -f $matches[1], $matches[2];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)1?[0-9]+m?_v([2-4])$' {
        $skuFamily = '{0} {1}v{2} Family vCPUs' -f $matches[1], $matches[2], $matches[3];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)?[0-9]+_v([2-4])_Promo$' {
        $skuFamily = '{0} {1}v{2} Promo Family vCPUs' -f $matches[1], $matches[2], $matches[3];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)1?[0-9]+_v([2-4])$' {
        $skuFamily = '{0} {1}v{2} Family vCPUs' -f $matches[1], $matches[2], $matches[3];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)1?[0-9]+m?s_v([2-4])$' {
        $skuFamily = '{0} {1}Sv{2} Family vCPUs' -f $matches[1], $matches[2], $matches[3];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)[0-9]+(-(1|2|4|8|16|32|64))?s_v([2-4])$' {
        $skuFamily = '{0} {1}Sv{2} Family vCPUs' -f $matches[1], $matches[2], $matches[5];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)S[0-9]+(-(1|2|4|8|16|32|64))?_v([2-4])$' {
        $skuFamily = '{0} {1}Sv{2} Family vCPUs' -f $matches[1], $matches[2], $matches[5];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)[0-9]+(-(1|2|4|8|16|32|64))?i_v([2-4])$' {
        $skuFamily = '{0} {1}Iv{2} Family vCPUs' -f $matches[1], $matches[2], $matches[5];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)[0-9]+(-(1|2|4|8|16|32|64))?is_v([2-4])$' {
        $skuFamily = '{0} {1}ISv{2} Family vCPUs' -f $matches[1], $matches[2], $matches[5];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)S[0-9]+_v([2-4])_Promo$' {
        $skuFamily = '{0} {1}Sv{2} Promo Family vCPUs' -f $matches[1], $matches[2], $matches[3];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)1?[0-9]+a_v([2-4])$' {
        $skuFamily = '{0} {1}Av{2} Family vCPUs' -f $matches[1], $matches[2], $matches[3];
        break;
      }
      '^(Basic|Standard)_(A|B|D|E|F|H|L|M)1?[0-9]+as_v([2-4])$' {
        $skuFamily = '{0} {1}ASv{2} Family vCPUs' -f $matches[1], $matches[2], $matches[3];
        break;
      }
      '^Standard_N([CV])[0-9]+r?$' {
        $skuFamily = 'Standard N{0} Family vCPUs' -f $matches[1];
        break;
      }
      '^Standard_N([CV])[0-9]+r?_Promo$' {
        $skuFamily = 'Standard N{0} Promo Family vCPUs' -f $matches[1];
        break;
      }
      '^Standard_N([DP])S[0-9]+$' {
        $skuFamily = 'Standard N{0}S Family vCPUs' -f $matches[1];
        break;
      }
      '^Standard_N([DP])[0-9]+r?s$' {
        $skuFamily = 'Standard N{0}S Family vCPUs' -f $matches[1];
        break;
      }
      '^Standard_N([CDV])[0-9]+r?s_v([2-4])$' {
        $skuFamily = 'Standard N{0}Sv{1} Family vCPUs' -f $matches[1], $matches[2];
        break;
      }
      default {
        $skuFamily = $null;
        break;
      }
    }
    if ($skuFamily) {
      Write-Debug -Message ('{0} :: azure sku family determined as {1} from sku {2}' -f $($MyInvocation.MyCommand.Name), $skuFamily, $sku);
    } else {
      Write-Debug -Message ('{0} :: failed to determine azure sku family from sku {1}' -f $($MyInvocation.MyCommand.Name), $sku);
    }
    return $skuFamily;
  }
  end {
    Write-Debug -Message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Get-PublicIpAddress {
  param (
    [string] $platform,
    [string] $group,
    [string] $resourceId
  )
  begin {
    Write-Debug -Message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    $publicIpAddress = $null;
    try {
      switch ($platform) {
        'azure' {
          $publicIpAddress = (Get-AzPublicIpAddress -ResourceGroupName $group -Name ('ip-{0}' -f $resourceId)).IpAddress;
          Write-Debug -Message ('{0} :: public ip address for resource: {1}, in group: {2}, on platform: {3}, determined as: {4}' -f $($MyInvocation.MyCommand.Name), $resourceId, $group, $platform, $publicIpAddress);
        }
        default {
          Write-Debug -Message ('{0} :: not implementated for platform: {1}' -f $($MyInvocation.MyCommand.Name), $platform);
        }
      }
    } catch {
      Write-Debug -Message ('{0} :: failed to determine public ip address for resource: {1}, in group: {2}, on platform: {3}. {4}' -f $($MyInvocation.MyCommand.Name), $resourceId, $group, $platform, $_.Exception.Message);
    }
    return $publicIpAddress;
  }
  end {
    Write-Debug -Message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Get-AdminPassword {
  param (
    [string] $platform,
    [string] $imageKey,
    [string] $uri = ('{0}/api/index/v1/task/project.relops.cloud-image-builder.{1}.{2}.latest/artifacts/public/unattend.xml' -f $env:TASKCLUSTER_ROOT_URL, $platform, $imageKey)
  )
  begin {
    Write-Debug -Message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    try {
      $memoryStream = (New-Object System.IO.MemoryStream(, (New-Object System.Net.WebClient).DownloadData($uri)));
      $streamReader = (New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode] 'Decompress')));
      [xml]$imageUnattendFileXml = [xml]$streamReader.ReadToEnd();
      Write-Debug -Message ('{0} :: unattend file for: {1}, on {2}, fetch and extraction from: {3}, suceeded' -f $($MyInvocation.MyCommand.Name), $imageKey, $platform, $uri);
    } catch {
      Write-Output -InputObject ('{0} :: unattend file for: {1}, on {2}, fetch and extraction from: {3}, failed. {4}' -f $($MyInvocation.MyCommand.Name), $imageKey, $platform, $uri, $_.Exception.Message);
      throw;
    }
    $administratorPassword = (($imageUnattendFileXml.unattend.settings | ? { $_.pass -eq 'oobeSystem' }).component | ? { $_.name -eq 'Microsoft-Windows-Shell-Setup' }).UserAccounts.AdministratorPassword;
    if ($administratorPassword.PlainText -eq 'false') {
      return (([System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($administratorPassword.Value))) -replace "`0", '').Replace('AdministratorPassword', '');
    }
    return $administratorPassword.Value;
  }
  end {
    Write-Debug -Message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Install-Dependencies {
  param (
    [hashtable[]] $dependencies = @(
      @{
        'name' = 'ruby-devkit';
        'download' = @{
          'source' = 'https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-2.6.6-1/rubyinstaller-devkit-2.6.6-1-x64.exe';
          'target' = 'C:\Windows\Temp\rubyinstaller-devkit-2.6.6-1-x64.exe'
        };
        'install' = @{
          'executable' = 'C:\Windows\Temp\rubyinstaller-devkit-2.6.6-1-x64.exe';
          'arguments' = @(
            '/verysilent',
            '/log=C:\log\install-ruby-stdout.log'
          );
          'stdout' = 'C:\log\install-ruby-devkit-stdout.log';
          'stderr' = 'C:\log\install-ruby-devkit-stderr.log';
          'wait' = @{
            'interval' = 10;
            'timeout' = 180;
          };
        };
        'validate' = @{
          'paths' = @(
            'C:\Ruby26-x64\bin\ruby.exe',
            'C:\Ruby26-x64\bin\gem.cmd',
            'C:\Ruby26-x64\msys64\var\log\pacman.log' # last entry in installation log
          )
        }
      };
      @{
        'name' = 'win32console';
        'install' = @{
          'executable' = 'C:\Ruby26-x64\bin\gem.cmd';
          'arguments' = @(
            'install',
            'win32console'
          );
          'stdout' = 'C:\log\install-win32console-stdout.log';
          'stderr' = 'C:\log\install-win32console-stderr.log';
        };
        'validate' = @{
          'paths' = @(
            'C:\Ruby26-x64\lib\ruby\gems\2.6.0\extensions\x64-mingw32\2.6.0\win32console-1.3.2\Console_ext.so'
          )
        }
      };
      @{
        'name' = 'papertrail-cli';
        'install' = @{
          'executable' = 'C:\Ruby26-x64\bin\gem.cmd';
          'arguments' = @(
            'install',
            'papertrail-cli'
          );
          'stdout' = 'C:\log\install-papertrail-cli-stdout.log';
          'stderr' = 'C:\log\install-papertrail-cli-stderr.log';
        };
        'validate' = @{
          'paths' = @(
            'C:\Ruby26-x64\bin\papertrail',
            'C:\Ruby26-x64\bin\papertrail.bat'
          )
        }
      }
    ),
    [int] $defaultTimeout = 60
  )
  begin {
    Write-Output -InputObject ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    foreach ($dependency in $dependencies) {
      if (@($dependency.validate.paths | ? { (-not (Test-Path -Path $_ -ErrorAction SilentlyContinue)) }).Length) {
        if ($dependency.ContainsKey('download') -and $dependency.download.ContainsKey('target') -and (-not (Test-Path -Path $dependency.download.target -ErrorAction SilentlyContinue))) {
          try {
            (New-Object Net.WebClient).DownloadFile($dependency.download.source, $dependency.download.target);
          } catch {
            Write-Output -InputObject ('{0} :: download of: {1}, to: {2}, failed. {3}' -f $($MyInvocation.MyCommand.Name), $dependency.download.source, $dependency.download.target, $_.Exception.Message);
            exit 123;
          }
          if (Test-Path -Path $dependency.download.target -ErrorAction SilentlyContinue) {
            Write-Output -InputObject ('{0} :: download of: {1}, to: {2}, suceeded.' -f $($MyInvocation.MyCommand.Name), $dependency.download.source, $dependency.download.target);
          } else {
            Write-Output -InputObject ('{0} :: download of: {1}, to: {2}, failed.' -f $($MyInvocation.MyCommand.Name), $dependency.download.source, $dependency.download.target);
            exit 123;
          }
        }
        $stopwatch = [Diagnostics.Stopwatch]::StartNew();
        try {
          $process = (Start-Process -FilePath $dependency.install.executable -ArgumentList $dependency.install.arguments -NoNewWindow -RedirectStandardOutput $dependency.install.stdout -RedirectStandardError $dependency.install.stderr -PassThru);
          Wait-Process -InputObject $process; # see: https://stackoverflow.com/a/43728914/68115
          Write-Output -InputObject ('{0} :: {1} - (`{2} {3}`) command exited with code: {4} after a processing time of: {5}.' -f $($MyInvocation.MyCommand.Name), [IO.Path]::GetFileNameWithoutExtension($dependency.install.executable), $dependency.install.executable, ([string[]]$dependency.install.arguments -join ' '), $(if ($process.ExitCode -or ($process.ExitCode -eq 0)) { $process.ExitCode } else { '-' }), $(if ($process.TotalProcessorTime -or ($process.TotalProcessorTime -eq 0)) { $process.TotalProcessorTime } else { '-' }));
          while (
            # await existence of all validation paths
            (@($dependency.validate.paths | ? { (-not (Test-Path -Path $_ -ErrorAction SilentlyContinue)) }).Length -gt 0) -and
            # stop waiting after configured timeout or default timeout ($defaultTimeout seconds)
            ($stopwatch.Elapsed.TotalSeconds -lt $(if ($dependency.install.ContainsKey('wait') -and $dependency.install.wait.ContainsKey('timeout')) { $dependency.install.wait.timeout } else { $defaultTimeout }))
          ) {
            foreach ($path in $dependency.validate.paths) {
              if (Test-Path -Path $path -ErrorAction SilentlyContinue) {
                Write-Output -InputObject ('{0} :: installation of dependency: {1}, in progress. detected existence of validation path: {2}.' -f $($MyInvocation.MyCommand.Name), $dependency.name, $path);
              } else {
                Write-Output -InputObject ('{0} :: installation of dependency: {1}, in progress. awaiting creation of validation path: {2}.' -f $($MyInvocation.MyCommand.Name), $dependency.name, $path);
              }
            }
          }
        } catch {
          Write-Output -InputObject ('{0} :: {1} - error executing command ({2} {3}). {4}' -f $($MyInvocation.MyCommand.Name), [IO.Path]::GetFileNameWithoutExtension($dependency.install.executable), $dependency.install.executable, ([string[]]$dependency.install.arguments -join ' '), $_.Exception.Message);
          exit 123;
        } finally {
          foreach ($stdStreamPath in @(@($dependency.install.stderr, $dependency.install.stdout) | ? { ((Test-Path $_ -PathType leaf -ErrorAction SilentlyContinue) -and ((Get-Item -Path $_ -ErrorAction SilentlyContinue).Length -le 0)) })) {
            Remove-Item -Path $stdStreamPath -ErrorAction SilentlyContinue;
          }
          $stopwatch.Stop();
        }
        if (@($dependency.validate.paths | ? { (-not (Test-Path -Path $_ -ErrorAction SilentlyContinue)) }).Length) {
          Write-Output -InputObject ('{0} :: installation of dependency: {1}, failed. not all validation paths exist after {2} seconds.' -f $($MyInvocation.MyCommand.Name), $dependency.name, $stopwatch.Elapsed.TotalSeconds);
          exit 123;
        }
      } else {
        Write-Output -InputObject ('{0} :: installation of dependency: {1}, skipped. all validation paths exist.' -f $($MyInvocation.MyCommand.Name), $dependency.name);
      }
    }
  }
  end {
    Write-Output -InputObject ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Get-Logs {
  param (
    [string[]] $systems,
    [string[]] $programs = @(
      'boostrap-puppet',
      'bootstrap',
      'dsc-run',
      'ed25519-public-key',
      'fluentd',
      'HaltOnIdle',
      'MaintainSystem',
      'nxlog',
      'OpenCloudConfig',
      'OpenSSH',
      'puppet',
      'puppet-run',
      'ronin',
      'Service_Control_Manager',
      'stderr',
      'stdout',
      'sysprep-cbs',
      'sysprep-ddaclsys',
      'sysprep-setupact',
      'sysprep-setupapi.app',
      'sysprep-setupapi.dev',
      'user32'
    ),
    [DateTime] $minTime = (Get-Date).AddHours(-3),
    [Nullable[DateTime]] $maxTime = $null,
    [string] $workFolder,
    [string] $papertrailCliPath = 'C:\Ruby26-x64\bin\papertrail.bat',
    [string] $token
  )
  begin {
    Write-Output -InputObject ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
    $env:PAPERTRAIL_API_TOKEN = $token;
  }
  process {
    foreach ($system in $systems) {
      foreach ($program in $programs) {
        $logSavePath = ('{0}{1}instance-logs{1}{2}-{3}-{4}.log' -f $workFolder, ([IO.Path]::DirectorySeparatorChar), $system, $program, $minTime.ToUniversalTime().ToString('yyyyMMddTHHmmssZ'));
        $errorPath = ('{0}{1}instance-logs{1}{2}-{3}-{4}-fetch-error.log' -f $workFolder, ([IO.Path]::DirectorySeparatorChar), $system, $program, $minTime.ToUniversalTime().ToString('yyyyMMddTHHmmssZ'));
        $argsList = @('--min-time', ('"{0} UTC"' -f $minTime.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')));
        if ($maxTime -ne $null) {
          $argsList += '--max-time';
          $argsList += ('"{0} UTC"' -f $maxTime.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'));
        }
        $argsList += ('"system:{0} program:{1}"' -f $system, $program);
        try {
          $process = (Start-Process -FilePath $papertrailCliPath -ArgumentList $argsList -NoNewWindow -RedirectStandardOutput $logSavePath -RedirectStandardError $errorPath -PassThru);
          Wait-Process -InputObject $process; # see: https://stackoverflow.com/a/43728914/68115
          Write-Output -InputObject ('{0} :: {1} - (`{2} {3}`) command exited with code: {4} after a processing time of: {5}.' -f $($MyInvocation.MyCommand.Name), [IO.Path]::GetFileNameWithoutExtension($papertrailCliPath), $papertrailCliPath, ([string[]]$argsList -join ' '), $(if ($process.ExitCode -or ($process.ExitCode -eq 0)) { $process.ExitCode } else { '-' }), $(if ($process.TotalProcessorTime -or ($process.TotalProcessorTime -eq 0)) { $process.TotalProcessorTime } else { '-' }));
          Write-Output -InputObject ('{0} :: {1} log messages retrieved for system: {2}, program: {3}' -f $($MyInvocation.MyCommand.Name), @(Get-Content -Path $logSavePath).Length, $system, $program);
          $standardErrorFile = (Get-Item -Path $errorPath -ErrorAction SilentlyContinue);
          if (($standardErrorFile) -and $standardErrorFile.Length) {
            Write-Output -InputObject ('{0} :: papertrail cli error: {1}' -f $($MyInvocation.MyCommand.Name), (Get-Content -Path $errorPath -Raw));
          }
        } catch {
          Write-Output -InputObject ('{0} :: {1} - error executing command ({2} {3}). {4}' -f $($MyInvocation.MyCommand.Name), [IO.Path]::GetFileNameWithoutExtension($papertrailCliPath), $papertrailCliPath, ([string[]]$argsList -join ' '), $_.Exception.Message);
        } finally {
          foreach ($stdStreamPath in @(@($logSavePath, $errorPath) | ? { ((Test-Path $_ -PathType leaf -ErrorAction SilentlyContinue) -and ((Get-Item -Path $_ -ErrorAction SilentlyContinue).Length -le 0)) })) {
            Remove-Item -Path $stdStreamPath -ErrorAction SilentlyContinue;
          }
        }
      }
    }
  }
  end {
    Remove-Item -Path 'Env:\PAPERTRAIL_API_TOKEN';
    Write-Output -InputObject ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Get-PublicKeys {
  param (
    [string[]] $systems,
    [string[]] $programs,
    [string] $workFolder,
    [hashtable[]] $regexes = @(
      @{
        'algorithm' = 'gpg';
        'pattern' = '-----BEGIN PGP PUBLIC KEY BLOCK-----.*-----END PGP PUBLIC KEY BLOCK-----'
      },
      @{
        'algorithm' = 'ed25519';
        'pattern' = '[A-Za-z0-9/+]{43}='
      }
    )
  )
  begin {
    Write-Output -InputObject ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    foreach ($system in $systems) {
      foreach ($program in $programs) {
        try {
          $logPath = ('{0}{1}instance-logs{1}{2}-{3}-*.log' -f $workFolder, ([IO.Path]::DirectorySeparatorChar), $system, $program);
          if (Test-Path -Path $logPath -ErrorAction SilentlyContinue) {
            $literalPaths = @(Resolve-Path -Path $logPath);
            if (($literalPaths) -and ($literalPaths.Length)) {
              foreach ($regex in $regexes) {
                $publicKeys = @(Get-Content $literalPaths | Select-String -Pattern '-----BEGIN PGP PUBLIC KEY BLOCK-----.*-----END PGP PUBLIC KEY BLOCK-----' | % { $_.Matches.Value });
                if (($publicKeys) -and ($publicKeys.Length)) {
                  $publicKeyFilePath = ('{0}{1}instance-logs{1}{2}-{3}-public.key' -f $workFolder, ([IO.Path]::DirectorySeparatorChar), $system, $regex.algorithm);
                  [System.IO.File]::WriteAllLines($publicKeyFilePath, @($publicKeys[0] -split '\s{2}'), (New-Object -TypeName 'System.Text.UTF8Encoding' -ArgumentList $false));
                  Write-Output -InputObject ('{0} :: {1} {2} public key(s) detected in {3}/{4} logs. saved first to {5}' -f $($MyInvocation.MyCommand.Name), $publicKeys.Length, $regex.algorithm, $system, $program, $publicKeyFilePath);
                } else {
                  Write-Output -InputObject ('{0} :: no {1} public key matches detected in {2}/{3} logs' -f $($MyInvocation.MyCommand.Name), $regex.algorithm, $system, $program);
                }
              }
            } else {
              Write-Output -InputObject ('{0} :: no {1}/{2} logs resolved with wildcard search "{3}"' -f $($MyInvocation.MyCommand.Name), $system, $program, $logPath);
            }
          } else {
            Write-Output -InputObject ('{0} :: no {1}/{2} logs detected with wildcard search "{3}"' -f $($MyInvocation.MyCommand.Name), $system, $program, $logPath);
          }
        } catch {
          Write-Output -InputObject ('{0} :: error parsing {1}/{2} logs for public keys. {3}' -f $($MyInvocation.MyCommand.Name), $system, $program, $_.Exception.Message);
        }
      }
    }
  }
  end {
    Write-Output -InputObject ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Remove-Image {
  param (
    [object] $image
  )
  begin {
    Write-Output -InputObject ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    try {
      Write-Output -InputObject ('{0} :: removing existing machine image {1} / {2} / {3}, created {4}' -f $($MyInvocation.MyCommand.Name), $image.Location, $image.ResourceGroupName, $image.Name, $image.Tags.machineImageCommitTime);
      if (Remove-AzImage `
        -ResourceGroupName $image.ResourceGroupName `
        -Name $image.Name `
        -AsJob `
        -Force) {
        Write-Output -InputObject ('{0} :: removed existing machine image {1} / {2} / {3}, created {4}' -f $($MyInvocation.MyCommand.Name), $image.Location, $image.ResourceGroupName, $image.Name, $image.Tags.machineImageCommitTime);
      } else {
        Write-Output -InputObject ('{0} :: failed to remove existing machine image {1} / {2} / {3}, created {4}' -f $($MyInvocation.MyCommand.Name), $image.Location, $image.ResourceGroupName, $image.Name, $image.Tags.machineImageCommitTime);
      }
    } catch {
      Write-Output -InputObject ('{0} :: exception removing existing machine image {1} / {2} / {3}, created {4}. {5}' -f $($MyInvocation.MyCommand.Name), $image.Location, $image.ResourceGroupName, $image.Name, $image.Tags.machineImageCommitTime, $_.Exception.Message);
    }
  }
  end {
    Write-Output -InputObject ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Publish-Screenshot {
  param (
    [string] $instanceName,
    [string] $groupName,
    [string] $platform,
    [string] $workFolder,
    [string] $savePathFull = ('{0}{1}screenshot{1}full' -f $workFolder, ([IO.Path]::DirectorySeparatorChar)),
    [string] $savePathThumb = ('{0}{1}screenshot{1}thumbnail' -f $workFolder, ([IO.Path]::DirectorySeparatorChar)),
    [hashtable[]] $resize = @(
      @{ 'width' = 128; 'height' = 96 },
      @{ 'width' =  64; 'height' = 48 }
    )
  )
  begin {
    Write-Output -InputObject ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
    if (-not (Test-Path -Path $savePathFull -ErrorAction SilentlyContinue)) {
      New-Item -ItemType 'Directory' -Force -Path $savePathFull;
    }
    if (-not (Test-Path -Path $savePathThumb -ErrorAction SilentlyContinue)) {
      New-Item -ItemType 'Directory' -Force -Path $savePathThumb;
    }
    try {
      Get-AzVMBootDiagnosticsData -ResourceGroupName $groupName -Name $instanceName -Windows -LocalPath $savePathFull -ErrorAction SilentlyContinue;
      foreach ($screenshot in (Get-ChildItem -Path $savePathFull -Filter '*.bmp')) {
        try {
          $pngPath = ('{0}{1}{2}-{3}.png' -f $savePathFull, ([IO.Path]::DirectorySeparatorChar), $instanceName, $screenshot.LastWriteTime.ToUniversalTime().ToString('yyyyMMddTHHmmssZ'));
          $bmpPath = $($screenshot.FullName);
          $image = [System.Drawing.Image]::FromFile($bmpPath);
          $image.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png);
          $image.Dispose();
          if (Test-Path -Path $pngPath -ErrorAction SilentlyContinue) {
            Write-Output -InputObject ('{0} :: screenshot converted from {1} to {2}' -f $($MyInvocation.MyCommand.Name), $bmpPath, $pngPath);
          } else {
            Write-Output -InputObject ('{0} :: failed to convert screenshot from {1} to {2}' -f $($MyInvocation.MyCommand.Name), $bmpPath, $pngPath);
          }
          Remove-Item -Path $bmpPath -Force;
          foreach ($size in $resize) {
            try {
              # generate a thumbnail
              $thumbnailPath = ('{0}{1}{2}-{3}-{4}x{5}.png' -f $savePathThumb, ([IO.Path]::DirectorySeparatorChar), $instanceName, $screenshot.LastWriteTime.ToUniversalTime().ToString('yyyyMMddTHHmmssZ'), $size.width, $size.height);
              $thumbnailBitmap = (New-Object -TypeName 'System.Drawing.Bitmap' -ArgumentList @($size.width, $size.height));
              $thumbnail = [System.Drawing.Graphics]::FromImage($thumbnailBitmap);
              $thumbnail.SmoothingMode = ([System.Drawing.Drawing2D.SmoothingMode]'HighQuality');
              $thumbnail.InterpolationMode = ([System.Drawing.Drawing2D.InterpolationMode]'HighQualityBicubic');
              $thumbnail.PixelOffsetMode = ([System.Drawing.Drawing2D.PixelOffsetMode]'HighQuality');
              $thumbnail.DrawImage($(New-Object -TypeName 'System.Drawing.Bitmap' -ArgumentList $pngPath), $(New-Object -TypeName 'System.Drawing.Rectangle' -ArgumentList @(0, 0, $size.width, $size.height)));
              $thumbnailBitmap.Save($thumbnailPath, [System.Drawing.Imaging.ImageFormat]::Png);
              $thumbnailBitmap.Dispose();
              $thumbnail.Dispose();
              Write-Output -InputObject ('{0} :: created thumbnail {1} from {2}' -f $($MyInvocation.MyCommand.Name), $thumbnailPath, $pngPath);
            } catch {
              Write-Output -InputObject ('{0} :: failed to create thumbnail {1} from {2}. {3}' -f $($MyInvocation.MyCommand.Name), $thumbnailPath, $pngPath, $_.Exception.Message);
            }
          }
        } catch {
          Write-Output -InputObject ('{0} :: failed to convert screenshot from {1} to {2}. {3}' -f $($MyInvocation.MyCommand.Name), $bmpPath, $pngPath, $_.Exception.Message);
        }
      }
    } catch {
      Write-Output -InputObject ('{0} :: failed to obtain boot diagnostics data for {1}/{2}/{3}. {4}' -f $($MyInvocation.MyCommand.Name), $platform, $groupName, $instanceName, $_.Exception.Message);
    }
  }
  end {
    Write-Output -InputObject ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

function Do-Stuff {
  param (
    [string] $arg1 = ''
  )
  begin {
    Write-Output -InputObject ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
  process {
  }
  end {
    Write-Output -InputObject ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime());
  }
}

# job settings. change these for the tasks at hand.
#$VerbosePreference = 'continue';
$workFolder = (Resolve-Path -Path ('{0}\..' -f $PSScriptRoot));
New-Item -ItemType 'Directory' -Force -Path ('{0}{1}instance-logs' -f $workFolder, ([IO.Path]::DirectorySeparatorChar));

# constants and script config. these are probably ok as they are.
$revision = $(& git rev-parse HEAD);
$revisionCommitDate = $(& git @('show', '-s', '--format=%ci', $revision));
Write-Output -InputObject ('workFolder: {0}, revision: {1}, platform: {2}, imageKey: {3}' -f $workFolder, $revision, $platform, $imageKey);

Update-RequiredModules;

$secret = (Invoke-WebRequest -Uri ('{0}/secrets/v1/secret/project/relops/image-builder/dev' -f $env:TASKCLUSTER_PROXY_URL) -UseBasicParsing | ConvertFrom-Json).secret;

Initialize-Platform -platform 'amazon' -secret $secret;
Initialize-Platform -platform $platform -secret $secret;
Install-Dependencies;

try {
  $config = (Get-Content -Path ('{0}\cloud-image-builder\config\{1}.yaml' -f $workFolder, $imageKey) -Raw | ConvertFrom-Yaml);
} catch {
  Write-Output -InputObject ('error: failed to find image config for {0}. {1}' -f $imageKey, $_.Exception.Message);
  exit 1
}
if ($config) {
  Write-Output -InputObject ('parsed image config for {0}' -f $imageKey);
} else {
  Write-Output -InputObject ('error: failed to find image config for {0}' -f $imageKey);
  exit 1
}
$imageArtifactDescriptor = (Get-ImageArtifactDescriptor -platform $platform -imageKey $imageKey);
$exportImageName = [System.IO.Path]::GetFileName($imageArtifactDescriptor.image.key);
$vhdLocalPath = ('{0}{1}{2}' -f $workFolder, ([IO.Path]::DirectorySeparatorChar), $exportImageName);

foreach ($target in @($config.target | ? { (($_.platform -eq $platform) -and $_.group -eq $group) })) {
  $bootstrapRevision = @($target.tag | ? { $_.name -eq 'deploymentId' })[0].value;
  if ($bootstrapRevision.Length -gt 7) {
    $bootstrapRevision = $bootstrapRevision.Substring(0, 7);
  }
  $targetImageName = ('{0}-{1}-{2}-{3}' -f $target.group.Replace('rg-', ''), $imageKey, $imageArtifactDescriptor.build.revision.Substring(0, 7), $bootstrapRevision);

  switch ($platform) {
    'azure' {
      $existingImage = (Get-AzImage `
        -ResourceGroupName $target.group `
        -ImageName $targetImageName `
        -ErrorAction SilentlyContinue);
      if ($existingImage) {
        if ($overwrite) {
          Remove-Image -image $existingImage
        } else {
          Write-Output -InputObject ('skipped machine image creation for: {0}, in group: {1}, in cloud platform: {2}. machine image exists' -f $targetImageName, $target.group, $target.platform);
          # prevent generic-worker from clasifying the task as failed due to missing artifacts
          New-Item -ItemType 'Directory' -Force -Path @(('{0}{1}screenshot{1}full' -f $workFolder, ([IO.Path]::DirectorySeparatorChar)), ('{0}{1}screenshot{1}thumbnail' -f $workFolder, ([IO.Path]::DirectorySeparatorChar)));
          New-Item -ItemType 'File' -Path @(('{0}{1}screenshot{1}full{1}intentionally-empty.txt' -f $workFolder, ([IO.Path]::DirectorySeparatorChar)), ('{0}{1}screenshot{1}thumbnail{1}intentionally-empty.txt' -f $workFolder, ([IO.Path]::DirectorySeparatorChar)));
          exit;
        }
      } elseif ($enableSnapshotCopy) {
        Invoke-SnapshotCopy -platform $platform -imageKey $imageKey -target $target -targetImageName $targetImageName -imageArtifactDescriptor $imageArtifactDescriptor
      }
    }
  }
  if (-not (Test-Path -Path $vhdLocalPath -ErrorAction SilentlyContinue)) {
    Get-CloudBucketResource `
      -platform $imageArtifactDescriptor.image.platform `
      -bucket $imageArtifactDescriptor.image.bucket `
      -key $imageArtifactDescriptor.image.key `
      -destination $vhdLocalPath `
      -force;
    if (Test-Path -Path $vhdLocalPath -ErrorAction SilentlyContinue) {
      Write-Output -InputObject ('download success for: {0} from: {1}/{2}/{3}' -f $vhdLocalPath, $imageArtifactDescriptor.image.platform, $imageArtifactDescriptor.image.bucket, $imageArtifactDescriptor.image.key);
    } else {
      Write-Output -InputObject ('download failure for: {0} from: {1}/{2}/{3}' -f $vhdLocalPath, $imageArtifactDescriptor.image.platform, $imageArtifactDescriptor.image.bucket, $imageArtifactDescriptor.image.key);
      exit 1;
    }
  }

  switch ($platform) {
    'azure' {
      $sku = ($target.machine.format -f $target.machine.cpu);
      if (-not (Get-AzComputeResourceSku | where { (($_.Locations -icontains $target.region.Replace(' ', '').ToLower()) -and ($_.Name -eq $sku)) })) {
        Write-Output -InputObject ('skipped image export: {0}, to region: {1}, in cloud platform: {2}. {3} is not available' -f $exportImageName, $target.region, $target.platform, $sku);
        exit 1;
      } else {
        $skuFamily = (Get-AzureSkuFamily -sku $sku);
        if ($skuFamily) {
          Write-Output -InputObject ('mapped machine sku: {0}, to machine family: {1}' -f $sku, $skuFamily);
          $azVMUsage = @(Get-AzVMUsage -Location $target.region | ? { $_.Name.LocalizedValue -eq $skuFamily })[0];
        } else {
          Write-Output -InputObject ('failed to map machine sku: {0}, to machine family (no regex match)' -f $sku);
          $azVMUsage = $false;
          exit 1;
        }
        if (-not $azVMUsage) {
          Write-Output -InputObject ('skipped image export: {0}, to region: {1}, in cloud platform: {2}. failed to obtain vm usage for machine sku: {3}, family: {4}' -f $exportImageName, $target.region, $target.platform, $sku, $skuFamily);
          exit 1;
        } elseif ($azVMUsage.Limit -lt ($azVMUsage.CurrentValue + $target.machine.cpu)) {
          Write-Output -InputObject ('skipped image export: {0}, to region: {1}, in cloud platform: {2}. {3}/{4} cores quota in use for machine sku: {5}, family: {6}. no capacity for requested aditional {7} cores' -f $exportImageName, $target.region, $target.platform, $azVMUsage.CurrentValue, $azVMUsage.Limit, $sku, $skuFamily, $target.machine.cpu);
          exit 123;
        } else {
          Write-Output -InputObject ('quota usage check: usage limit: {0}, usage current value: {1}, core request: {2}, for machine sku: {3}, family: {4}' -f $azVMUsage.Limit, $azVMUsage.CurrentValue, $target.machine.cpu, $sku, $skuFamily);
          try {
            Write-Output -InputObject ('begin image export: {0}, to region: {1}, in cloud platform: {2}' -f $exportImageName, $target.region, $target.platform);
            switch ($target.hostname.slug.type) {
              'disk-image-sha' {
                $resourceId = ($imageArtifactDescriptor.build.revision.Substring(0, $target.hostname.slug.length));
                $instanceName = ($target.hostname.format -f $resourceId);
                break;
              }
              'machine-image-sha' {
                $resourceId = ($revision.Substring(0, $target.hostname.slug.length));
                $instanceName = ($target.hostname.format -f $resourceId);
                break;
              }
              'uuid' {
                $resourceId = (([Guid]::NewGuid()).ToString().Substring((36 - $target.hostname.slug.length)));
                $instanceName = ($target.hostname.format -f $resourceId);
                break;
              }
              default {
                $resourceId = (([Guid]::NewGuid()).ToString().Substring(24));
                $instanceName = ('vm-{0}' -f $resourceId);
                break;
              }
            }
            $tags = @{
              'diskImageCommitTime' = (Get-Date -Date $imageArtifactDescriptor.build.time -UFormat '+%Y-%m-%dT%H:%M:%S%Z');
              'diskImageCommitSha' = $imageArtifactDescriptor.build.revision;
              'machineImageCommitTime' = (Get-Date -Date $revisionCommitDate -UFormat '+%Y-%m-%dT%H:%M:%S%Z');
              'machineImageCommitSha' = $revision;
              'machineImageTask' = ('{0}/{1}' -f $env:TASK_ID, $env:RUN_ID);
              'imageKey' = $imageKey;
              'resourceId' = $resourceId;
              'os' = $config.image.os;
              'edition' = $config.image.edition;
              'language' = $config.image.language;
              'architecture' = $config.image.architecture;
              'isoIndex' = $config.iso.wimindex;
              'isoName' = ([System.IO.Path]::GetFileName($config.iso.source.key))
            };
            foreach ($tag in $target.tag) {
              $tags[$tag.name] = $tag.value;
            }
            if ($imageArtifactDescriptor.build.task) {
              $tags['diskImageTask'] = ('{0}/{1}' -f $imageArtifactDescriptor.build.task.id, $imageArtifactDescriptor.build.task.run);
            }

            # check (again) that another task hasn't already created the image
            $existingImage = (Get-AzImage `
              -ResourceGroupName $target.group `
              -ImageName $targetImageName `
              -ErrorAction SilentlyContinue);
            if ($existingImage) {
              if ($overwrite) {
                Remove-Image -image $existingImage
              } else {
                Write-Output -InputObject ('skipped machine image creation for: {0}, in group: {1}, in cloud platform: {2}. machine image exists' -f $targetImageName, $target.group, $target.platform);
                exit;
              }
            }

            $newCloudInstanceInstantiationAttempts = 0;
            do {
              $logMinTime = (Get-Date);
              New-CloudInstanceFromImageExport `
                -platform $target.platform `
                -localImagePath $vhdLocalPath `
                -targetResourceId $resourceId `
                -targetResourceGroupName $target.group `
                -targetResourceRegion $target.region `
                -targetInstanceMachineVariantFormat $target.machine.format `
                -targetInstanceCpuCount $target.machine.cpu `
                -targetInstanceRamGb $target.machine.ram `
                -targetInstanceName $instanceName `
                -targetInstanceDisks @($target.disk | % {@{ 'Variant' = $_.variant; 'SizeInGB' = $_.size; 'Os' = $_.os }}) `
                -targetInstanceTags $tags `
                -targetVirtualNetworkName $target.network.name `
                -targetVirtualNetworkAddressPrefix $target.network.prefix `
                -targetVirtualNetworkDnsServers $target.network.dns `
                -targetSubnetName $target.network.subnet.name `
                -targetSubnetAddressPrefix $target.network.subnet.prefix `
                -targetFirewallConfigurationName $target.network.flow.name `
                -targetFirewallRules $target.network.flow.rules `
                -disablePlatformAgent:($target.agent -eq 'disabled') `
                -disableBackgroundInfo:($target.agent -eq 'disabled');

              $newCloudInstanceInstantiationAttempts += 1;
              $azVm = (Get-AzVm -ResourceGroupName $target.group -Name $instanceName -ErrorAction SilentlyContinue);
              if ($azVm) {
                if (@('Succeeded', 'Failed') -contains $azVm.ProvisioningState) {
                  Write-Output -InputObject ('provisioning of vm: {0}, {1} on attempt: {2}' -f $instanceName, $azVm.ProvisioningState.ToLower(), $newCloudInstanceInstantiationAttempts);
                } else {
                  Write-Output -InputObject ('provisioning of vm: {0}, in progress with state: {1} on attempt: {2}' -f $instanceName, $azVm.ProvisioningState.ToLower(), $newCloudInstanceInstantiationAttempts);
                  Start-Sleep -Seconds 60
                }
              } else {
                # if we reach here, we most likely hit an azure quota exception which we may recover from when some quota becomes available.
                if (-not $disableCleanup) {
                  Remove-Resource -resourceId $resourceId -resourceGroupName $target.group;
                }
                try {
                  $taskDefinition = (Invoke-WebRequest -Uri ('{0}/api/queue/v1/task/{1}' -f $env:TASKCLUSTER_ROOT_URL, $env:TASK_ID) -UseBasicParsing | ConvertFrom-Json);
                  [DateTime] $taskStart = $taskDefinition.created;
                  [DateTime] $taskExpiry = $taskStart.AddSeconds($taskDefinition.payload.maxRunTime);
                  if ($taskExpiry -lt (Get-Date).AddMinutes(30)) {
                    Write-Output -InputObject ('provisioning of vm: {0}, failed on attempt: {1}. passing control to task retry logic...' -f $instanceName, $newCloudInstanceInstantiationAttempts);
                    exit 123;
                  }
                } catch {
                  Write-Output -InputObject ('failed to determine task expiry time using root url {0} and task id: {1}. {2}' -f $env:TASKCLUSTER_ROOT_URL, $env:TASK_ID, $_.Exception.Message);
                }
                $sleepInSeconds = (Get-Random -Minimum (3 * 60) -Maximum (10 * 60));
                Write-Output -InputObject ('provisioning of vm: {0}, failed on attempt: {1}. retrying in {2:1} minutes...' -f $instanceName, $newCloudInstanceInstantiationAttempts, ($sleepInSeconds / 60));
                Start-Sleep -Seconds $sleepInSeconds;
              }
            } until (@('Succeeded', 'Failed') -contains $azVm.ProvisioningState)
            Write-Output -InputObject ('end image export: {0} to: {1} cloud platform' -f $exportImageName, $target.platform);

            # await first shutdown by sysprep reseal trigger.
            if (($config.image.reseal.mode -eq 'Audit') -and ($config.image.reseal.shutdown)) {
              # image is configured for sysprep audit mode and must be started after its first sysprep shutdown
              while ((Get-InstanceStatus -instanceName $instanceName -groupName $target.group -ErrorAction 'SilentlyContinue').Code -notmatch 'PowerState/stopped') {
                Write-Output -InputObject ('awaiting shutdown. image configured for sysprep reseal audit mode with shutdown. current state: {0}' -f (Get-InstanceStatus -instanceName $instanceName -groupName $target.group -ErrorAction 'SilentlyContinue').Code);
                Publish-Screenshot -instanceName $instanceName -groupName $target.group -platform $target.platform -workFolder $workFolder;
                Start-Sleep -Seconds 60;
              }
              Write-Output -InputObject ('first shutdown detected (triggered by oobe/reseal). current state: {0}' -f (Get-InstanceStatus -instanceName $instanceName -groupName $target.group -ErrorAction 'SilentlyContinue').Code);
              # start instance in audit mode for bootstrapping.
              try {
                $instanceStartOperation = (Start-AzVM -ResourceGroupName $target.group -Name $instanceName);
                if ($instanceStartOperation.Status -eq 'Succeeded') {
                  Write-Output -InputObject ('instance restart triggered after sysprep reseal to audit mode (from oobe) shutdown. current state: {0}' -f (Get-InstanceStatus -instanceName $instanceName -groupName $target.group -ErrorAction 'SilentlyContinue').Code);
                } else {
                  Write-Output -InputObject ('instance restart failed after sysprep reseal to audit mode (from oobe) shutdown. current state: {0}' -f (Get-InstanceStatus -instanceName $instanceName -groupName $target.group -ErrorAction 'SilentlyContinue').Code);
                  if (-not $disableCleanup) {
                    Remove-Resource -resourceId $resourceId -resourceGroupName $target.group;
                  }
                  exit 123;
                }
              } catch {
                Write-Output -InputObject ('instance restart failed after sysprep reseal to audit mode (from oobe) shutdown. current state: {0}. {1}' -f (Get-InstanceStatus -instanceName $instanceName -groupName $target.group -ErrorAction 'SilentlyContinue').Code, $_.Exception.Message);
              }
              while ((Get-InstanceStatus -instanceName $instanceName -groupName $target.group -ErrorAction 'SilentlyContinue').Code -ne 'PowerState/running') {
                Write-Output -InputObject ('awaiting instance running state after sysprep reseal to audit mode (from oobe) shutdown and restart. current state: {0}' -f (Get-InstanceStatus -instanceName $instanceName -groupName $target.group -ErrorAction 'SilentlyContinue').Code);
                Start-Sleep -Seconds 30;
              }
              $azVm = (Get-AzVm -ResourceGroupName $target.group -Name $instanceName -ErrorAction SilentlyContinue);
            }
            if ($azVm -and ($azVm.ProvisioningState -eq 'Succeeded')) {
              Publish-Screenshot -instanceName $instanceName -groupName $target.group -platform $target.platform -workFolder $workFolder;
              Write-Output -InputObject ('begin image import: {0} in region: {1}, cloud platform: {2}' -f $targetImageName, $target.region, $target.platform);
              if ($target.bootstrap.executions) {
                Invoke-BootstrapExecutions -instanceName $instanceName -groupName $target.group -executions $target.bootstrap.executions -flow $target.network.flow -disableCleanup:$disableCleanup;
              } else {
                Write-Output -InputObject ('no bootstrap command execution configurations detected for: {0}/{1}' -f $target.group, $instanceName);
              }
              # check (again) that another task hasn't already created the image
              $existingImage = (Get-AzImage `
                -ResourceGroupName $target.group `
                -ImageName $targetImageName `
                -ErrorAction SilentlyContinue);
              if ($existingImage) {
                if ($overwrite) {
                  Remove-Image -image $existingImage
                } else {
                  Write-Output -InputObject ('skipped machine image creation for: {0}, in group: {1}, in cloud platform: {2}. machine image exists' -f $targetImageName, $target.group, $target.platform);
                  exit;
                }
              }

              # await final shutdown after audit mode completion
              if ($config.image.generalize.shutdown) {
                # make regular instance status observations, wait until instance has remained in the stopped state for 60 seconds
                $instanceStatusObservations = @{};
                $stopwatch = [Diagnostics.Stopwatch]::StartNew();
                Write-Output -InputObject 'awaiting final shutdown (determined by instance remaining in stopped state for 60 seconds) after sysprep generalize settings pass has completed.';
                while (
                  # make instance status observations for at least 60 seconds
                  ($stopwatch.Elapsed.TotalSeconds -lt 60) -or
                  # require that all state observations in the preceeding 60 seconds show a stopped state
                  (@($instanceStatusObservations.Keys | ? { $_ -gt ((Get-Date).ToUniversalTime().AddSeconds(-60).ToString('yyyyMMddHHmmss')) } | % { $instanceStatusObservations[$_] } | ? { $_ -ne 'PowerState/stopped' }).Length)
                ) {
                  # make an instance status observation
                  $instanceStatusObservationTime = (Get-Date).ToUniversalTime();
                  $instanceStatus = (Get-InstanceStatus -instanceName $instanceName -groupName $target.group -ErrorAction 'SilentlyContinue');
                  $instanceStatusObservations.Add($instanceStatusObservationTime.ToString('yyyyMMddHHmmss'), $instanceStatus.Code);
                  Write-Output -InputObject ('instance status observed as: {0}, at: {1} utc' -f $instanceStatus.Code, $instanceStatusObservationTime.ToString('HH:mm:ss'));
                  Publish-Screenshot -instanceName $instanceName -groupName $target.group -platform $target.platform -workFolder $workFolder;
                  Start-Sleep -Seconds 1;
                }
                $stopwatch.Stop();
                Write-Output -InputObject ('final shutdown detected (triggered by generalize). current state: {0}' -f (Get-InstanceStatus -instanceName $instanceName -groupName $target.group -ErrorAction 'SilentlyContinue').Code);
              }

              # system name can change during the course of bootstrapping, get system logs for conventional names
              $fqdnPool = @($target.tag | ? { $_.name -eq 'workerType' })[0].value;
              $fqdnRegion = $target.region.Replace(' ', '').ToLower();
              $systems = @(
                ('{0}.reddog.microsoft.com' -f $config.image.hostname), # default fqdn, when sysprep unattend does not contain DNSDomain element
                ('{0}.{1}' -f $config.image.hostname, $config.image.network.dns.domain), # conventional (cib) fqdn, when sysprep unattend does contain DNSDomain element
                ('{0}.{1}.{2}.mozilla.com' -f $config.image.hostname, $fqdnPool, $fqdnRegion), # conventional fqdn, when cib has set the hostname and bootstrap has set the domain
                ('{0}.{1}.{2}.mozilla.com' -f $instanceName, $fqdnPool, $fqdnRegion), # conventional (bootstrap) fqdn, when bootstrap has set the hostname and domain
                ('{0}.{1}.mozilla.com' -f $fqdnPool, $fqdnRegion) # catch logs forwarded before sysprep has renamed the system
              );
              Write-Output -InputObject 'waiting 5 minutes for instance log ingestion at papertrail';
              Start-Sleep -Seconds (5 * 60);
              if ($config.log) {
                Get-Logs -minTime $logMinTime -systems $systems -programs $config.log -workFolder $workFolder -token $secret.papertrail.token;
              } else {
                Get-Logs -minTime $logMinTime -systems $systems -workFolder $workFolder -token $secret.papertrail.token;
              }
              Get-PublicKeys -systems $systems -programs @('ed25519-public-key', 'MaintainSystem') -workFolder $workFolder;

              $imageBuildTaskValidations = [hashtable[]] @();
              if ($config.validation -and $config.validation.instance -and $config.validation.instance.log) {
                Write-Output -InputObject ('{0} :: {1} image log validation rules detected' -f $($MyInvocation.MyCommand.Name), ([System.Object[]]@($config.validation.instance.log)).Length);
                foreach ($rule in $config.validation.instance.log) {
                  $logCandidatesPath = ('{0}{1}instance-logs' -f $workFolder, ([IO.Path]::DirectorySeparatorChar));
                  $logCandidatesFilter = ('{0}.{1}.{2}.mozilla.com-{3}-*.log' -f $instanceName, $fqdnPool, $fqdnRegion, $rule.program);
                  $logCandidates = @(Get-ChildItem -Path $logCandidatesPath -Filter $logCandidatesFilter);
                  $imageBuildTaskValidations += @{
                    'program' = $rule.program;
                    'path' = $(if (($logCandidates) -and ($logCandidates.Length)) { $logCandidates[0].FullName } else { $logCandidatesPath });
                    'filter' = $logCandidatesFilter;
                    'match' = $rule.match;
                    # result = true if log file exists and contains match, else false
                    'result' = (($logCandidates) -and ($logCandidates.Length) -and (((Get-Content -Path $logCandidates[0].FullName) | % {($_ -match $rule.match)}) -contains $true))
                  };
                }
              } else {
                Write-Output -InputObject ('{0} :: no image log validation rules detected' -f $($MyInvocation.MyCommand.Name));
              }
              $imageBuildTaskValidationFailures = @($imageBuildTaskValidations | ? { (-not ($_.result)) });
              $imageBuildTaskValidationSuccesses = @($imageBuildTaskValidations | ? { ($_.result) });
              if ($imageBuildTaskValidationFailures.Length -gt 0) {
                Write-Output -InputObject ('image: {0}, failed {1}/{2} validation rules' -f $targetImageName, $imageBuildTaskValidationFailures.Length, $imageBuildTaskValidations.Length);
                foreach ($imageBuildTaskValidationFailure in $imageBuildTaskValidationFailures) {
                  if (($imageBuildTaskValidationFailure.path) -and ($imageBuildTaskValidationFailure.path.EndsWith('.log'))) {
                    Write-Output -InputObject ('log file for program: {0}, at path: {1}, did not contain a match for: "{2}"' -f $imageBuildTaskValidationFailure.program, $imageBuildTaskValidationFailure.path, $imageBuildTaskValidationFailure.match);
                  } else {
                    Write-Output -InputObject ('log file for program: {0}, at path: {1}, using filter: "{2}" was missing' -f $imageBuildTaskValidationFailure.program, $imageBuildTaskValidationFailure.path, $imageBuildTaskValidationFailure.filter);
                  }
                }
                if (-not $disableCleanup) {
                  Remove-Resource -resourceId $resourceId -resourceGroupName $target.group;
                }
                exit 123;
              } else {
                Write-Output -InputObject ('image: {0}, passed {1}/{2} validation rules' -f $targetImageName, $imageBuildTaskValidationSuccesses.Length, $imageBuildTaskValidations.Length);
              }

              # detach data disks from vm before machine image capture
              $dataDiskNames = @(Get-AzDisk -ResourceGroupName $target.group | ? { $_.Name -match ('^{0}-data-disk-[0-9]$' -f $instanceName) -and $_.OsType -eq $null } | % { $_.Name });
              if ($dataDiskNames.Length) {
                try {
                  $removeDataDisksOperation = (Remove-AzVMDataDisk `
                    -VM $azVm `
                    -DataDiskNames $dataDiskNames);
                  if (($removeDataDisksOperation.ProvisioningState -eq 'Succeeded') -and ((Update-AzVM -ResourceGroupName $target.group -VM $azVm).IsSuccessStatusCode)) {
                    Write-Output -InputObject ('detached: {0} data disks ({1}) from {2}' -f $dataDiskNames.Length, [string]::Join(', ', $dataDiskNames), $instanceName);
                  } else {
                    Write-Output -InputObject ('failed to detach: {0} data disks ({1}) from {2}' -f $dataDiskNames.Length, [string]::Join(', ', $dataDiskNames), $instanceName);
                  }
                } catch {
                  Write-Output -InputObject ('failed to detach: {0} data disks ({1}) from {2}. {3}' -f $dataDiskNames.Length, [string]::Join(', ', $dataDiskNames), $instanceName, $_.Exception.Message);
                }
              }
              New-CloudImageFromInstance `
                -platform $target.platform `
                -resourceGroupName $target.group `
                -region $target.region `
                -instanceName $instanceName `
                -imageName $targetImageName `
                -imageTags $tags;
              try {
                $azImage = (Get-AzImage `
                  -ResourceGroupName $target.group `
                  -ImageName $targetImageName `
                  -ErrorAction SilentlyContinue);
                if ($azImage) {
                  Write-Output -InputObject ('image: {0}, creation appears successful in region: {1}, cloud platform: {2}' -f $targetImageName, $target.region, $target.platform);
                } else {
                  Write-Output -InputObject ('image: {0}, creation appears unsuccessful in region: {1}, cloud platform: {2}' -f $targetImageName, $target.region, $target.platform);
                  if (-not $disableCleanup) {
                    Remove-Resource -resourceId $resourceId -resourceGroupName $target.group;
                  }
                  exit 1;
                }
              } catch {
                Write-Output -InputObject ('image: {0}, fetch threw exception in region: {1}, cloud platform: {2}. {3}' -f $targetImageName, $target.region, $target.platform, $_.Exception.Message);
                if (-not $disableCleanup) {
                  Remove-Resource -resourceId $resourceId -resourceGroupName $target.group;
                }
                exit 1;
              }
              if ($enableSnapshotCopy) {
                try {
                  $azVm = (Get-AzVm `
                    -ResourceGroupName $target.group `
                    -Name $instanceName `
                    -Status `
                    -ErrorAction SilentlyContinue);
                  if (($azVm) -and (@($azVm.Statuses | ? { ($_.Code -eq 'OSState/generalized') -or ($_.Code -eq 'PowerState/deallocated') }).Length -eq 2)) {
                    # create a snapshot
                    # todo: move this functionality to posh-minions-managed
                    $azVm = (Get-AzVm `
                      -ResourceGroupName $target.group `
                      -Name $instanceName `
                      -ErrorAction SilentlyContinue);
                    if ($azVm -and $azVm.StorageProfile.OsDisk.Name) {
                      $azDisk = (Get-AzDisk `
                        -ResourceGroupName $target.group `
                        -DiskName $azVm.StorageProfile.OsDisk.Name);
                      if ($azDisk -and $azDisk[0].Id) {
                        $azSnapshotConfig = (New-AzSnapshotConfig `
                          -SourceUri $azDisk[0].Id `
                          -CreateOption 'Copy' `
                          -Location $target.region.Replace(' ', '').ToLower());
                        $azSnapshot = (New-AzSnapshot `
                          -ResourceGroupName $target.group `
                          -Snapshot $azSnapshotConfig `
                          -SnapshotName $targetImageName);
                      } else {
                        Write-Output -InputObject ('provisioning of snapshot: {0}, from instance: {1}, skipped due to undetermined osdisk id' -f $targetImageName, $instanceName);
                      }
                    } else {
                      Write-Output -InputObject ('provisioning of snapshot: {0}, from instance: {1}, skipped due to undetermined osdisk name' -f $targetImageName, $instanceName);
                    }
                    Write-Output -InputObject ('provisioning of snapshot: {0}, from instance: {1}, has state: {2}' -f $targetImageName, $instanceName, $azSnapshot.ProvisioningState.ToLower());
                  } else {
                    Write-Output -InputObject ('provisioning of snapshot: {0}, from instance: {1}, skipped due to undetermined vm state' -f $targetImageName, $instanceName);
                  }
                } catch {
                  Write-Output -InputObject ('provisioning of snapshot: {0}, from instance: {1}, threw exception. {2}' -f $targetImageName, $instanceName, $_.Exception.Message);
                } finally {
                  if (-not $disableCleanup) {
                    Remove-Resource -resourceId $resourceId -resourceGroupName $target.group;
                  }
                }
              } else {
                Write-Output -InputObject ('snapshot creation skipped because enableSnapshotCopy is set to false');
              }
              Write-Output -InputObject ('end image import: {0} in region: {1}, cloud platform: {2}' -f $targetImageName, $target.region, $target.platform);
            } else {
              Write-Output -InputObject ('skipped image import: {0} in region: {1}, cloud platform: {2}' -f $targetImageName, $target.region, $target.platform);
              if (-not $disableCleanup) {
                Remove-Resource -resourceId $resourceId -resourceGroupName $target.group;
              }
              exit 1;
            }
          } catch {
            Write-Output -InputObject ('error: failure in image export: {0}, to region: {1}, in cloud platform: {2}. {3}' -f $exportImageName, $target.region, $target.platform, $_.Exception.Message);
            if (-not $disableCleanup) {
              Remove-Resource -resourceId $resourceId -resourceGroupName $target.group;
            }
            exit 1;
          } finally {
            if (-not $disableCleanup) {
              Remove-Resource -resourceId $resourceId -resourceGroupName $target.group;
            }
          }
        }
      }
    }
  }
}
