(this["webpackJsonpcloud-image-builder-react"]=this["webpackJsonpcloud-image-builder-react"]||[]).push([[0],{48:function(t,e,a){t.exports=a(70)},56:function(t,e,a){},70:function(t,e,a){"use strict";a.r(e);var n=a(1),s=a.n(n),r=a(11),i=a.n(r),o=(a(53),a(54),a(55),a(56),a(2)),u=a(7),c=a(8),l=a(10),m=a(9),p=a(29),d=a(30),h=a(46),g=a(12),f=a(27),k=a(26),b=a(13),y=a(19),j=a(42),O=a(20),v=a(23),E=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(){return Object(u.a)(this,a),e.apply(this,arguments)}return Object(c.a)(a,[{key:"render",value:function(){var t=this;return s.a.createElement("div",null,this.props.message.filter((function(t){return!t.match(new RegExp("^(include|exclude) (environment|key|pool|region)s: .*$","i"))&&!t.match(new RegExp("^(pool-deploy|overwrite-disk-image|overwrite-machine-image|disable-cleanup|purge-taskcluster-resources|no-ci|no-taskcluster-ci|no-travis-ci)$","i"))})).map((function(t,e){return 0===e?t.match(/bug ([0-9]{5,8})/i)?s.a.createElement("span",{key:e},s.a.createElement("a",{href:"https://bugzilla.mozilla.org/show_bug.cgi?id="+t.match(/bug ([0-9]{5,8})/i)[1],target:"_blank",rel:"noopener noreferrer"},t.match(/bug ([0-9]{5,8})/i)[0])," ",t.replace(t.match(/bug ([0-9]{5,8})/i)[0],""),s.a.createElement("br",null)):s.a.createElement("strong",{key:e},t,s.a.createElement("br",null)):t.match(/bug ([0-9]{5,8})/i)?s.a.createElement("span",{key:e},s.a.createElement("a",{href:"https://bugzilla.mozilla.org/show_bug.cgi?id="+t.match(/bug ([0-9]{5,8})/i)[1],target:"_blank",rel:"noopener noreferrer"},t.match(/bug ([0-9]{5,8})/i)[0])," ",t.replace(t.match(/bug ([0-9]{5,8})/i)[0],""),s.a.createElement("br",null)):s.a.createElement("span",{key:e},t,s.a.createElement("br",null))})),this.props.message.some((function(t){return t.match(/^(include|exclude) (environment|key|pool|region)s: .*$/i)||t.match(/^(pool-deploy|overwrite-disk-image|overwrite-machine-image|disable-cleanup|purge-taskcluster-resources|no-ci|no-taskcluster-ci|no-travis-ci)$/i)}))?this.props.message.filter((function(t){return t.match(/^(pool-deploy|overwrite-disk-image|overwrite-machine-image|disable-cleanup|purge-taskcluster-resources|no-ci|no-taskcluster-ci|no-travis-ci)$/i)})).map((function(t){return s.a.createElement(b.a,{key:t,style:{marginRight:"0.7em"},variant:["pool-deploy","overwrite-disk-image","overwrite-machine-image","disable-cleanup","purge-taskcluster-resources"].includes(t)?"primary":"dark"},t)})):s.a.createElement(b.a,{variant:"warning"},"no commit syntax ci instructions"),["include","exclude"].map((function(e){return t.props.message.some((function(t){return t.match(new RegExp("^"+e+" (environment|key|pool|region)s: .*$","i"))}))?s.a.createElement("span",{key:e},["environments","integrations","keys","pools","regions"].map((function(a){return t.props.message.filter((function(t){return t.startsWith(e+" "+a+": ")})).map((function(t,n){return t.replace(e+" "+a+": ","").split(", ").map((function(t){return s.a.createElement(b.a,{key:n,style:{marginRight:"0.7em"},variant:"include"===e?"info":"dark",title:e+" "+a.slice(0,-1)+": "+t},"include"===e?s.a.createElement(v.d,null):s.a.createElement(v.c,null),"\xa0",t)}))}))})),s.a.createElement("br",null)):""})))}}]),a}(s.a.Component),x=a(14),w=a(16),S=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(){var t;Object(u.a)(this,a);for(var n=arguments.length,s=new Array(n),r=0;r<n;r++)s[r]=arguments[r];return(t=e.call.apply(e,[this].concat(s))).re=/^((north|south|east|west|(north-|south-|west-)?central)-us(-2)?)-(.*)-(win.*)-([a-f0-9]{7})-([a-f0-9]{7})$/i,t.state={domain:null,pool:null,region:null,sha:{bootstrap:null,disk:null}},t}return Object(c.a)(a,[{key:"componentDidMount",value:function(){var t=this.props.image.substring(this.props.image.lastIndexOf("/")+1).match(this.re);this.setState((function(e){return{domain:t[5],pool:t[6],region:t[1],sha:{bootstrap:t[8],disk:t[7]}}}))}},{key:"render",value:function(){return s.a.createElement("li",null,s.a.createElement("a",{href:"https://portal.azure.com/#@taskclusteraccountsmozilla.onmicrosoft.com/resource"+this.props.image,target:"_blank",rel:"noopener noreferrer"},this.state.region,"-",this.state.domain,"-",this.state.pool,"-",this.state.sha.disk,"-",this.state.sha.bootstrap))}}]),a}(s.a.Component),I=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(){return Object(u.a)(this,a),e.apply(this,arguments)}return Object(c.a)(a,[{key:"render",value:function(){return s.a.createElement("div",null,s.a.createElement("span",null,"worker manager image deployments:"),s.a.createElement("ul",null,this.props.images.map((function(t){return s.a.createElement(S,{image:t,key:t})}))))}}]),a}(s.a.Component),T=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(){var t;Object(u.a)(this,a);for(var n=arguments.length,s=new Array(n),r=0;r<n;r++)s[r]=arguments[r];return(t=e.call.apply(e,[this].concat(s))).state={logs:[]},t}return Object(c.a)(a,[{key:"componentDidMount",value:function(){var t=this;this.setState((function(e){return{logs:t.props.logs.map((function(e){return{name:e.name,contentType:e.contentType,url:"https://artifacts.tcstage.mozaws.net/"+t.props.taskId+"/"+t.props.runId+"/"+e.name}}))}}))}},{key:"render",value:function(){return s.a.createElement("ul",null,this.state.logs.map((function(t){return s.a.createElement("li",{key:t.name},s.a.createElement("a",{href:t.url,target:"_blank",rel:"noopener noreferrer"},t.name))})))}}]),a}(s.a.Component),C=a(41),z=a.n(C),W=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(){var t;Object(u.a)(this,a);for(var n=arguments.length,s=new Array(n),r=0;r<n;r++)s[r]=arguments[r];return(t=e.call.apply(e,[this].concat(s))).state={screenshots:[],thumbnailPosition:window.innerWidth<960?"bottom":"left",galleryWidth:window.innerWidth<960?640:698},t.updateDimensions=function(){window.innerWidth<960?t.setState((function(t){return{thumbnailPosition:"bottom",galleryWidth:640}})):t.setState((function(t){return{thumbnailPosition:"left",galleryWidth:698}}))},t}return Object(c.a)(a,[{key:"componentDidMount",value:function(){var t=this;window.addEventListener("resize",this.updateDimensions),this.setState((function(e){return{screenshots:t.props.screenshots.map((function(e){return{original:"https://artifacts.tcstage.mozaws.net/"+t.props.taskId+"/"+t.props.runId+"/"+e.name,originalAlt:e.name.split("/").pop().replace(/\.[^/.]+$/,"").replace("-"," "),originalTitle:e.name.split("/").pop().replace(/\.[^/.]+$/,"").replace("-"," "),thumbnail:"https://artifacts.tcstage.mozaws.net/"+t.props.taskId+"/"+t.props.runId+"/"+e.name.replace("/full/","/thumbnail/").replace(".png","-64x48.png"),thumbnailAlt:e.name.split("/").pop().replace(/\.[^/.]+$/,"").replace("-"," "),thumbnailTitle:e.name.split("/").pop().replace(/\.[^/.]+$/,"").replace("-"," ")}}))}}))}},{key:"componentWillUnmount",value:function(){window.removeEventListener("resize",this.updateDimensions)}},{key:"render",value:function(){return s.a.createElement("div",{style:{width:this.state.galleryWidth+"px"}},s.a.createElement(z.a,{items:this.state.screenshots,startIndex:this.state.screenshots.length-1,thumbnailPosition:this.state.thumbnailPosition}))}}]),a}(s.a.Component),_={completed:"success",failed:"danger",exception:"warning",running:"primary",pending:"info",unscheduled:"secondary"},R=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(t){var n;return Object(u.a)(this,a),(n=e.call(this,t)).state={summary:{task:{completed:{},failed:{},exception:{},running:{},pending:{},unscheduled:{}},image:{}},artifacts:[],logs:[],screenshots:[],images:[]},n.appendToSummary=n.appendToSummary.bind(Object(g.a)(n)),n}return Object(c.a)(a,[{key:"appendToSummary",value:function(t){var e=this;this.setState((function(a){var n={task:{completed:Object(o.a)(Object(o.a)({},a.summary.task.completed),t.task.completed),failed:Object(o.a)(Object(o.a)({},a.summary.task.failed),t.task.failed),exception:Object(o.a)(Object(o.a)({},a.summary.task.exception),t.task.exception),running:Object(o.a)(Object(o.a)({},a.summary.task.running),t.task.running),pending:Object(o.a)(Object(o.a)({},a.summary.task.pending),t.task.pending),unscheduled:Object(o.a)(Object(o.a)({},a.summary.task.unscheduled),t.task.unscheduled)},image:Object(o.a)(Object(o.a)({},a.summary.image),t.image)};return e.props.appender(n),{summary:n}}))}},{key:"componentDidMount",value:function(){var t=this;fetch(this.props.rootUrl+"/api/queue/v1/task/"+this.props.taskId+"/runs/"+this.props.run.runId+"/artifacts").then((function(t){return t.json()})).then((function(e){if(e.artifacts&&e.artifacts.length&&(t.setState((function(t){return{artifacts:e.artifacts,logs:e.artifacts.filter((function(t){return t.contentType.startsWith("text/plain")&&t.name.startsWith("public/instance-logs/")&&t.name.endsWith(".log")})),screenshots:e.artifacts.filter((function(t){return"image/png"===t.contentType&&t.name.startsWith("public/screenshot/full/")&&t.name.endsWith(".png")}))}})),e.artifacts.some((function(t){return t.name.startsWith("public/")&&t.name.endsWith(".json")})))){var a=e.artifacts.find((function(t){return t.name.startsWith("public/")&&t.name.endsWith(".json")}));fetch(t.props.rootUrl+"/api/queue/v1/task/"+t.props.taskId+"/runs/"+t.props.run.runId+"/artifacts/"+a.name).then((function(t){return t.json()})).then((function(e){if(e.launchConfigs&&e.launchConfigs.length){var a=e.launchConfigs.map((function(t){return t.storageProfile.imageReference.id}));t.setState((function(t){return{images:a}}));var n=/^((north|south|east|west|(north-|south-|east-|west-)?central)-us(-2)?)-(.*)-(win.*)-([a-f0-9]{7})-([a-f0-9]{7})$/i;t.appendToSummary({task:{completed:0,failed:0,exception:0,running:0,pending:0,unscheduled:0},image:a.reduce((function(t,e,a){var s=e.substring(e.lastIndexOf("/")+1).match(n),r=s[5]+"/"+s[6];return t[r]=(t[r]||0)+1,t}),{})})}})).catch(console.log)}})).catch(console.log)}},{key:"render",value:function(){return s.a.createElement("li",null,s.a.createElement(y.a,{size:"sm",href:this.props.rootUrl+"/tasks/"+this.props.taskId+"/runs/"+this.props.run.runId,style:{marginLeft:"0.7em"},variant:"outline-"+_[this.props.run.state],title:"task "+this.props.taskId+", run "+this.props.run.runId+": "+this.props.run.state},"task "+this.props.taskId+", run "+this.props.run.runId),this.props.taskName.startsWith("03")&&this.state.images.length?s.a.createElement(I,{images:this.state.images}):"",this.props.taskName.startsWith("02")&&this.state.screenshots.length?"completed"===this.props.run.state||"failed"===this.props.run.state?s.a.createElement(W,{screenshots:this.state.screenshots,taskId:this.props.taskId,runId:this.props.run.runId}):s.a.createElement("a",{style:{marginLeft:"1em"},href:"https://stage.taskcluster.nonprod.cloudops.mozgcp.net/tasks/"+this.props.taskId+"#artifacts",target:"_blank",rel:"noopener noreferrer"},"screenshots"):this.props.taskName.startsWith("02")?"completed"===this.props.run.state||"failed"===this.props.run.state?"":s.a.createElement("div",{style:{width:"100%"}},s.a.createElement(O.a,{animation:"grow",variant:"secondary",size:"sm"})):"",this.props.taskName.startsWith("02")&&this.state.logs.length?s.a.createElement(T,{logs:this.state.logs,taskId:this.props.taskId,runId:this.props.run.runId}):"")}}]),a}(s.a.Component),U=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(t){var n;return Object(u.a)(this,a),(n=e.call(this,t)).state={summary:{task:{completed:{},failed:{},exception:{},running:{},pending:{},unscheduled:{}},image:{}}},n.appendToSummary=n.appendToSummary.bind(Object(g.a)(n)),n}return Object(c.a)(a,[{key:"appendToSummary",value:function(t){var e=this;this.setState((function(a){var n={task:{completed:Object(o.a)(Object(o.a)({},a.summary.task.completed),t.task.completed),failed:Object(o.a)(Object(o.a)({},a.summary.task.failed),t.task.failed),exception:Object(o.a)(Object(o.a)({},a.summary.task.exception),t.task.exception),running:Object(o.a)(Object(o.a)({},a.summary.task.running),t.task.running),pending:Object(o.a)(Object(o.a)({},a.summary.task.pending),t.task.pending),unscheduled:Object(o.a)(Object(o.a)({},a.summary.task.unscheduled),t.task.unscheduled)},image:Object(o.a)(Object(o.a)({},a.summary.image),t.image)};return e.props.appender(n),{summary:n}}))}},{key:"render",value:function(){var t=this;return s.a.createElement("ul",null,this.props.runs.map((function(e){return s.a.createElement(R,{run:e,key:e.runId,taskId:t.props.taskId,taskName:t.props.taskName,rootUrl:t.props.rootUrl,appender:t.appendToSummary})})))}}]),a}(s.a.Component),D=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(t){var n;return Object(u.a)(this,a),(n=e.call(this,t)).state={summary:{task:{completed:{},failed:{},exception:{},running:{},pending:{},unscheduled:{}},image:{}}},n.appendToSummary=n.appendToSummary.bind(Object(g.a)(n)),n}return Object(c.a)(a,[{key:"appendToSummary",value:function(t){var e=this;this.setState((function(a){var n={task:{completed:Object(o.a)(Object(o.a)({},a.summary.task.completed),t.task.completed),failed:Object(o.a)(Object(o.a)({},a.summary.task.failed),t.task.failed),exception:Object(o.a)(Object(o.a)({},a.summary.task.exception),t.task.exception),running:Object(o.a)(Object(o.a)({},a.summary.task.running),t.task.running),pending:Object(o.a)(Object(o.a)({},a.summary.task.pending),t.task.pending),unscheduled:Object(o.a)(Object(o.a)({},a.summary.task.unscheduled),t.task.unscheduled)},image:Object(o.a)(Object(o.a)({},a.summary.image),t.image)};return e.props.appender(n),{summary:n}}))}},{key:"render",value:function(){var t=this;return s.a.createElement("li",null,this.props.task.task.metadata.name,"\xa0",s.a.createElement("a",{href:this.props.rootUrl+"/tasks/"+this.props.task.status.taskId,title:this.props.task.status.taskId},this.props.task.status.taskId.substring(0,7),"..."),Array.from(new Set(this.props.task.status.runs.map((function(t){return t.state})))).map((function(e){return s.a.createElement(b.a,{key:e,style:{margin:"0 1px"},variant:_[e],title:e+": "+t.props.task.status.runs.filter((function(t){return t.state===e})).length},t.props.task.status.runs.filter((function(t){return t.state===e})).length)})),s.a.createElement(U,{runs:this.props.task.status.runs,taskId:this.props.task.status.taskId,taskName:this.props.task.task.metadata.name,rootUrl:this.props.rootUrl,appender:this.appendToSummary}))}}]),a}(s.a.Component),L=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(t){var n;return Object(u.a)(this,a),(n=e.call(this,t)).state={summary:{task:{completed:{},failed:{},exception:{},running:{},pending:{},unscheduled:{}},image:{}}},n.appendToSummary=n.appendToSummary.bind(Object(g.a)(n)),n}return Object(c.a)(a,[{key:"appendToSummary",value:function(t){var e=this;this.setState((function(a){var n={task:{completed:Object(o.a)(Object(o.a)({},a.summary.task.completed),t.task.completed),failed:Object(o.a)(Object(o.a)({},a.summary.task.failed),t.task.failed),exception:Object(o.a)(Object(o.a)({},a.summary.task.exception),t.task.exception),running:Object(o.a)(Object(o.a)({},a.summary.task.running),t.task.running),pending:Object(o.a)(Object(o.a)({},a.summary.task.pending),t.task.pending),unscheduled:Object(o.a)(Object(o.a)({},a.summary.task.unscheduled),t.task.unscheduled)},image:Object(o.a)(Object(o.a)({},a.summary.image),t.image)};return e.props.appender(n),{summary:n}}))}},{key:"render",value:function(){var t=this;return s.a.createElement("ul",null,this.props.tasks.sort((function(t,e){return t.task.metadata.name<e.task.metadata.name?-1:t.task.metadata.name>e.task.metadata.name?1:0})).filter((function(e){return!t.props.settings.limit.tasks||t.props.settings.limit.tasks.includes(e.task.metadata.name.slice(0,2))})).map((function(e){return s.a.createElement(D,{task:e,key:e.status.taskId,rootUrl:t.props.rootUrl,appender:t.appendToSummary})})))}}]),a}(s.a.Component),N=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(t){var n;return Object(u.a)(this,a),(n=e.call(this,t)).state={summary:{task:{completed:{},failed:{},exception:{},running:{},pending:{},unscheduled:{}},image:{}},taskGroupId:null,taskCount:0,tasks:[],builds:[],travisApiResponse:{}},n.travisBuildResults=["completed","failed"],n.appendToSummary=n.appendToSummary.bind(Object(g.a)(n)),n}return Object(c.a)(a,[{key:"appendToSummary",value:function(t){var e=this;this.setState((function(a){var n={task:{completed:Object(o.a)(Object(o.a)({},a.summary.task.completed),t.task.completed),failed:Object(o.a)(Object(o.a)({},a.summary.task.failed),t.task.failed),exception:Object(o.a)(Object(o.a)({},a.summary.task.exception),t.task.exception),running:Object(o.a)(Object(o.a)({},a.summary.task.running),t.task.running),pending:Object(o.a)(Object(o.a)({},a.summary.task.pending),t.task.pending),unscheduled:Object(o.a)(Object(o.a)({},a.summary.task.unscheduled),t.task.unscheduled)},image:Object(o.a)(Object(o.a)({},a.summary.image),t.image)};return e.props.appender(n),{summary:n}}))}},{key:"componentDidMount",value:function(){var t=this;switch(this.props.status.context){case"continuous-integration/travis-ci/push":var e=new URL(this.props.status.target_url).pathname,a=e.substring(e.lastIndexOf("/")+1);this.setState((function(t){return{taskGroupId:a}})),fetch("https://api.travis-ci.org/repos/mozilla-platform-ops/cloud-image-builder/builds/"+a).then((function(t){return t.json()})).then((function(e){e.matrix&&(t.setState((function(t){return{taskCount:e.matrix.length,builds:e.matrix,travisApiResponse:e}})),t.appendToSummary({task:{completed:Object(o.a)({},e.matrix.filter((function(t){return 0===t.result})).map((function(t){return[t.id,t.finished_at]})).reduce((function(t,e){var a=Object(w.a)(e,2),n=a[0],s=a[1];return Object(o.a)(Object(o.a)({},t),{},Object(x.a)({},n,s))}),{})),failed:Object(o.a)({},e.matrix.filter((function(t){return null!==t.result&&0!==t.result})).map((function(t){return[t.id,t.finished_at]})).reduce((function(t,e){var a=Object(w.a)(e,2),n=a[0],s=a[1];return Object(o.a)(Object(o.a)({},t),{},Object(x.a)({},n,s))}),{})),exception:{},running:{},pending:Object(o.a)({},e.matrix.filter((function(t){return null===t.result})).map((function(t){return[t.id,t.finished_at]})).reduce((function(t,e){var a=Object(w.a)(e,2),n=a[0],s=a[1];return Object(o.a)(Object(o.a)({},t),{},Object(x.a)({},n,s))}),{})),unscheduled:{}},image:[]}))})).catch(console.log);break;default:var n=new URL(this.props.status.target_url),s=this.props.status.target_url.substring(this.props.status.target_url.lastIndexOf("/")+1);this.setState((function(t){return{taskGroupId:s}}));var r="https://"+n.hostname+"/api/queue/v1/task-group/"+s+"/list";fetch(r).then((function(t){return t.json()})).then((function(e){e.tasks&&e.tasks.length&&(t.setState((function(t){return{taskCount:e.tasks.length,tasks:e.tasks}})),t.appendToSummary({task:{completed:Object(o.a)({},e.tasks.filter((function(t){return"completed"===t.status.state})).map((function(t){return[t.status.taskId,t.status.runs[t.status.runs.length-1].resolved]})).reduce((function(t,e){var a=Object(w.a)(e,2),n=a[0],s=a[1];return Object(o.a)(Object(o.a)({},t),{},Object(x.a)({},n,s))}),{})),failed:Object(o.a)({},e.tasks.filter((function(t){return"failed"===t.status.state})).map((function(t){return[t.status.taskId,t.status.runs[t.status.runs.length-1].resolved]})).reduce((function(t,e){var a=Object(w.a)(e,2),n=a[0],s=a[1];return Object(o.a)(Object(o.a)({},t),{},Object(x.a)({},n,s))}),{})),exception:Object(o.a)({},e.tasks.filter((function(t){return"exception"===t.status.state})).map((function(t){return[t.status.taskId,t.status.runs[t.status.runs.length-1].resolved]})).reduce((function(t,e){var a=Object(w.a)(e,2),n=a[0],s=a[1];return Object(o.a)(Object(o.a)({},t),{},Object(x.a)({},n,s))}),{})),running:Object(o.a)({},e.tasks.filter((function(t){return"running"===t.status.state})).map((function(t){return[t.status.taskId,null]})).reduce((function(t,e){var a=Object(w.a)(e,2),n=a[0],s=a[1];return Object(o.a)(Object(o.a)({},t),{},Object(x.a)({},n,s))}),{})),pending:Object(o.a)({},e.tasks.filter((function(t){return"pending"===t.status.state})).map((function(t){return[t.status.taskId,null]})).reduce((function(t,e){var a=Object(w.a)(e,2),n=a[0],s=a[1];return Object(o.a)(Object(o.a)({},t),{},Object(x.a)({},n,s))}),{})),unscheduled:Object(o.a)({},e.tasks.filter((function(t){return"unscheduled"===t.status.state})).map((function(t){return[t.status.taskId,null]})).reduce((function(t,e){var a=Object(w.a)(e,2),n=a[0],s=a[1];return Object(o.a)(Object(o.a)({},t),{},Object(x.a)({},n,s))}),{}))},image:[]}))})).catch(console.log)}}},{key:"render",value:function(){var t=this;return s.a.createElement("li",null,new Intl.DateTimeFormat("en-GB",{year:"numeric",month:"short",day:"2-digit",hour:"numeric",minute:"numeric",timeZoneName:"short"}).format(new Date(this.props.status.updated_at)),"\xa0",this.props.status.description.toLowerCase(),"\xa0 (",this.state.taskCount," tasks in group \xa0",s.a.createElement("a",{href:this.props.status.target_url,title:this.state.taskGroupId},this.state.builds.length?this.state.taskGroupId:(this.state.taskGroupId&&this.state.taskGroupId.slice(0,7))+"..."),"\xa0",Object.keys(_).map((function(e){return t.state.tasks.filter((function(t){return t.status.state===e})).length?s.a.createElement(b.a,{key:e,style:{margin:"0 1px"},variant:_[e],title:e+": "+t.state.tasks.filter((function(t){return t.status.state===e})).length},t.state.tasks.filter((function(t){return t.status.state===e})).length):""})),[0,1,null].map((function(e,a){return t.state.builds.filter((function(t){return t.result===e})).length?s.a.createElement(b.a,{key:a,style:{margin:"0 1px"},variant:null===e?"info":_[t.travisBuildResults[e]],title:t.travisBuildResults[e]+": "+t.state.builds.filter((function(t){return t.result===e})).length},t.state.builds.filter((function(t){return t.result===e})).length):""})),")",s.a.createElement(L,{tasks:this.state.tasks,rootUrl:"https://"+new URL(this.props.status.target_url).hostname,appender:this.appendToSummary,settings:this.props.settings}))}}]),a}(s.a.Component),$=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(t){var n;return Object(u.a)(this,a),(n=e.call(this,t)).state={summary:{task:{completed:{},failed:{},exception:{},running:{},pending:{},unscheduled:{}},image:{}}},n.appendToSummary=n.appendToSummary.bind(Object(g.a)(n)),n}return Object(c.a)(a,[{key:"appendToSummary",value:function(t){var e=this;this.setState((function(a){var n={task:{completed:Object(o.a)(Object(o.a)({},a.summary.task.completed),t.task.completed),failed:Object(o.a)(Object(o.a)({},a.summary.task.failed),t.task.failed),exception:Object(o.a)(Object(o.a)({},a.summary.task.exception),t.task.exception),running:Object(o.a)(Object(o.a)({},a.summary.task.running),t.task.running),pending:Object(o.a)(Object(o.a)({},a.summary.task.pending),t.task.pending),unscheduled:Object(o.a)(Object(o.a)({},a.summary.task.unscheduled),t.task.unscheduled)},image:Object(o.a)(Object(o.a)({},a.summary.image),t.image)};return e.props.appender(n),{summary:n}}))}},{key:"render",value:function(){var t=this;return s.a.createElement("ul",null,this.props.contexts.map((function(e,a){return s.a.createElement("li",{key:a,style:{margin:"10px 0 0 0",padding:"0 0 0 40px",listStyle:"none",backgroundImage:'url("'+t.props.statuses.find((function(t){return t.context===e})).avatar_url+'")',backgroundRepeat:"no-repeat",backgroundPosition:"left top",backgroundSize:"30px"}},e,s.a.createElement("ul",null,t.props.statuses.some((function(t){return t.context===e&&"pending"!==t.state}))?t.props.statuses.filter((function(t){return t.context===e&&"pending"!==t.state})).map((function(e){return s.a.createElement(N,{status:e,key:e.id,appender:t.appendToSummary,settings:t.props.settings})})):t.props.statuses.filter((function(t){return t.context===e})).map((function(e){return s.a.createElement(N,{status:e,key:e.id,appender:t.appendToSummary,settings:t.props.settings})}))))})))}}]),a}(s.a.Component),A=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(t){var n;return Object(u.a)(this,a),(n=e.call(this,t)).state={summary:{task:{completed:{},failed:{},exception:{},running:{},pending:{},unscheduled:{}},image:{}},contexts:[],statuses:[],expanded:!1},n.appendToSummary=n.appendToSummary.bind(Object(g.a)(n)),n}return Object(c.a)(a,[{key:"appendToSummary",value:function(t){this.setState((function(e){return{summary:{task:{completed:Object(o.a)(Object(o.a)({},e.summary.task.completed),t.task.completed),failed:Object(o.a)(Object(o.a)({},e.summary.task.failed),t.task.failed),exception:Object(o.a)(Object(o.a)({},e.summary.task.exception),t.task.exception),running:Object(o.a)(Object(o.a)({},e.summary.task.running),t.task.running),pending:Object(o.a)(Object(o.a)({},e.summary.task.pending),t.task.pending),unscheduled:Object(o.a)(Object(o.a)({},e.summary.task.unscheduled),t.task.unscheduled)},image:Object(o.a)(Object(o.a)({},e.summary.image),t.image)}}}))}},{key:"componentDidMount",value:function(){var t=this;this.setState((function(e){return{expanded:t.props.expand}}));var e=Math.floor(55e3*Math.random())+5e3;this.interval=setInterval(this.getBuildStatuses.bind(this),e)}},{key:"componentWillUnmount",value:function(){clearInterval(this.interval)}},{key:"getBuildStatuses",value:function(){var t=this;fetch("localhost"===window.location.hostname?"http://localhost:8010/proxy/repos/mozilla-platform-ops/cloud-image-builder/commits/"+this.props.commit.sha+"/statuses":"https://grenade-cors-proxy.herokuapp.com/https://api.github.com/repos/mozilla-platform-ops/cloud-image-builder/commits/"+this.props.commit.sha+"/statuses").then((function(t){return t.json()})).then((function(e){e.length&&t.setState((function(t){return{contexts:Object(h.a)(new Set(e.map((function(t){return t.context})))).sort((function(t,e){return t.toLowerCase().localeCompare(e.toLowerCase())})),statuses:e}}))})).catch(console.log)}},{key:"render",value:function(){var t=this;return s.a.createElement(f.a,{style:{width:"100%",marginTop:"10px"}},s.a.createElement(f.a.Header,null,s.a.createElement(k.a.Toggle,{as:y.a,variant:"link",eventKey:this.props.commit.sha,onClick:function(){t.setState((function(t){return{expanded:!t.expanded}}))}},this.state.expanded?s.a.createElement(v.a,null):s.a.createElement(v.b,null)),new Intl.DateTimeFormat("en-GB",{year:"numeric",month:"short",day:"2-digit",hour:"numeric",minute:"numeric",timeZoneName:"short"}).format(new Date(this.props.commit.committer.date)),"\xa0",s.a.createElement("a",{href:this.props.commit.url},this.props.commit.sha.substring(0,7)),Object.keys(this.state.summary.task).some((function(e){return Object.keys(t.state.summary.task[e]).length>0}))?Object.keys(this.state.summary.task).filter((function(e){return Object.keys(t.state.summary.task[e]).length>0})).map((function(e){return s.a.createElement(b.a,{key:e,style:{marginLeft:"0.3em"},variant:_[e]},Object.keys(t.state.summary.task[e]).length)})):s.a.createElement(O.a,{style:{marginLeft:"0.3em"},animation:"border",size:"sm",variant:"info"}),s.a.createElement(j.a,{src:this.props.commit.author.avatar,alt:this.props.commit.author.name,title:this.props.commit.author.name,rounded:!0,style:{width:"30px",height:"30px",marginLeft:"10px"},className:"float-right"}),s.a.createElement("span",{className:"float-right"},this.props.commit.author.username)),Object.keys(this.state.summary.image).length?s.a.createElement(f.a.Body,null,Object.keys(this.state.summary.image).sort().map((function(e){return s.a.createElement(y.a,{key:e,style:{marginLeft:"0.3em"},variant:"outline-info",size:"sm"},e," ",s.a.createElement(b.a,{variant:"info"},t.state.summary.image[e]))}))):"",s.a.createElement(k.a.Collapse,{eventKey:this.props.commit.sha},s.a.createElement(f.a.Body,null,s.a.createElement(E,{message:this.props.commit.message}),s.a.createElement($,{contexts:this.state.contexts,statuses:this.state.statuses,appender:this.appendToSummary,settings:this.props.settings}))))}}]),a}(s.a.Component),B=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(){return Object(u.a)(this,a),e.apply(this,arguments)}return Object(c.a)(a,[{key:"render",value:function(){var t=this;return this.props.commits.length?s.a.createElement(k.a,{defaultActiveKey:null},this.props.commits.map((function(e){return s.a.createElement(A,{commit:e,key:e.sha,expand:!1,settings:t.props.settings})}))):s.a.createElement("div",{style:{textAlign:"center",width:"100%",padding:"100px"}},s.a.createElement(O.a,{animation:"border"}))}}]),a}(s.a.Component),M=a(25),G=a(44),P=a(37),q=a(36),K=a(47),F=a(45),J=function(t){Object(l.a)(a,t);var e=Object(m.a)(a);function a(){var t;Object(u.a)(this,a);for(var n=arguments.length,s=new Array(n),r=0;r<n;r++)s[r]=arguments[r];return(t=e.call.apply(e,[this].concat(s))).cookies=new K.a,t.state={commits:[],settings:{fluid:void 0===t.cookies.get("fluid")||null===t.cookies.get("fluid")||"true"===t.cookies.get("fluid"),limit:void 0===t.cookies.get("limit")||null===t.cookies.get("limit")?{commits:1,tasks:["03","04"]}:t.cookies.get("limit")}},t}return Object(c.a)(a,[{key:"componentDidMount",value:function(){void 0!==this.cookies.get("fluid")&&null!==this.cookies.get("fluid")||this.cookies.set("fluid",!0,{path:"/",sameSite:"strict"}),void 0!==this.cookies.get("limit")&&null!==this.cookies.get("limit")||this.cookies.set("limit",this.state.settings.limit,{path:"/",sameSite:"strict"}),console.log("componentDidMount()"),console.log(this.state),this.getCommits(this.state.settings.limit.commits);this.interval=setInterval(this.getCommits.bind(this),3e5)}},{key:"componentWillUnmount",value:function(){clearInterval(this.interval)}},{key:"getCommits",value:function(t){var e=this;null!==t&&void 0!==t||(t=1),console.log("getCommits()"),console.log(this.state),fetch("localhost"===window.location.hostname?"http://localhost:8010/proxy/repos/mozilla-platform-ops/cloud-image-builder/commits":"https://grenade-cors-proxy.herokuapp.com/https://api.github.com/repos/mozilla-platform-ops/cloud-image-builder/commits").then((function(t){return t.json()})).then((function(a){a.length&&e.setState((function(e){return{commits:a.slice(0,t).map((function(t){return{sha:t.sha,url:t.html_url,author:Object(o.a)(Object(o.a)({},t.commit.author),{id:t.author.id,username:t.author.login,avatar:t.author.avatar_url}),committer:Object(o.a)(Object(o.a)({},t.commit.committer),{id:t.committer.id,username:t.committer.login,avatar:t.committer.avatar_url}),message:t.commit.message.split("\n").filter((function(t){return""!==t})),verification:t.commit.verification}})),latest:a[0].sha}}))})).catch(console.log)}},{key:"render",value:function(){var t=this;return s.a.createElement(G.a,{fluid:void 0===this.state.settings.fluid||null===this.state.settings.fluid||this.state.settings.fluid},s.a.createElement(q.a,null,s.a.createElement("h1",{style:{padding:"0 1em"}},s.a.createElement(p.a,{style:{marginRight:"0.4em"},icon:d.a}),s.a.createElement(p.a,{style:{marginRight:"0.4em"},icon:d.c}),s.a.createElement(p.a,{style:{marginRight:"0.4em"},icon:d.b}),"recent commits and builds")),s.a.createElement(q.a,null,s.a.createElement(M.a,null,s.a.createElement(B,{commits:this.state.commits,latest:this.state.latest,settings:this.state.settings})),s.a.createElement(M.a,{sm:"2"},s.a.createElement("strong",null,"legend"),s.a.createElement("br",{style:{marginTop:"20px"}}),"task status:",Object.keys(_).map((function(t){return s.a.createElement(b.a,{key:t,style:{display:"block",margin:"10px 20px"},variant:_[t]},t)})),"image deployment:",s.a.createElement("br",null),s.a.createElement(y.a,{style:{marginLeft:"0.3em"},variant:"outline-info",size:"sm"},"worker pool ",s.a.createElement(b.a,{variant:"info"},"region count")),s.a.createElement("hr",null),s.a.createElement("strong",null,"display settings:"),s.a.createElement("br",null),s.a.createElement(F.a,{defaultValue:this.state.settings.limit.commits,min:1,max:30,onChange:function(e){var a={commits:e,tasks:t.state.settings.limit.tasks};t.cookies.set("limit",a,{path:"/",sameSite:"strict"}),t.setState((function(t){return{settings:{fluid:t.settings.fluid,limit:a}}})),t.getCommits(e)},style:{marginTop:"20px"}}),"limit commits (",this.state.settings.limit.commits,")",s.a.createElement("br",{style:{marginBottom:"20px"}}),s.a.createElement(P.a.Check,{type:"switch",id:"showAllTasks",label:"all tasks",checked:this.state.settings.limit.tasks.length>2,onChange:function(){var e={commits:t.state.settings.limit.commits,tasks:t.state.settings.limit.tasks.length>2?["03","04"]:["00","01","02","03","04"]};t.cookies.set("limit",e,{path:"/",sameSite:"strict"}),t.setState((function(t){return{settings:{fluid:t.settings.fluid,limit:e}}}))}}),s.a.createElement("br",null),s.a.createElement(P.a.Check,{type:"switch",id:"fluid",label:"fluid",checked:this.state.settings.fluid,onChange:function(){var e=!t.state.settings.fluid;t.cookies.set("fluid",e,{path:"/",sameSite:"strict"}),t.setState((function(t){return{settings:{fluid:e,limit:t.settings.limit}}}))}}),s.a.createElement("hr",null),s.a.createElement("p",{className:"text-muted"},"this page monitors ",s.a.createElement("a",{href:"https://github.com/mozilla-platform-ops/cloud-image-builder/commits/master"},"commits")," to the master branch of the ",s.a.createElement("a",{href:"https://github.com/mozilla-platform-ops/cloud-image-builder"},"mozilla-platform-ops/cloud-image-builder")," repository and the resulting travis-ci builds and taskcluster tasks which produce cloud machine images of the various windows operating system editions and configurations used by firefox ci to build and test gecko products on the windows platform."),s.a.createElement("p",{className:"text-muted"},"the source code for this page is hosted in the ",s.a.createElement("a",{href:"https://github.com/mozilla-platform-ops/cloud-image-builder/tree/react"},"react branch")," of the same repository."))))}}]),a}(s.a.Component);Boolean("localhost"===window.location.hostname||"[::1]"===window.location.hostname||window.location.hostname.match(/^127(?:\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}$/));i.a.render(s.a.createElement(s.a.StrictMode,null,s.a.createElement(J,null)),document.getElementById("root")),"serviceWorker"in navigator&&navigator.serviceWorker.ready.then((function(t){t.unregister()})).catch((function(t){console.error(t.message)}))}},[[48,1,2]]]);
//# sourceMappingURL=main.163f9108.chunk.js.map