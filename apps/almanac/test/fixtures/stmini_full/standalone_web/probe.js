"use strict";
let sequence=0;
const pending=new Map();
const documentNonce=String(Date.now())+":"+Math.random();
window.CMSJsCallBack=function(response){const done=pending.get(response.methodId);if(done){pending.delete(response.methodId);done(response)}};
function call(method,params={}){return new Promise((resolve,reject)=>{const methodId="web-"+(++sequence);pending.set(methodId,resolve);setTimeout(()=>{if(pending.delete(methodId))reject(new Error("timeout:"+method))},5000);window.webkit.messageHandlers.CMSScriptMessageChannel.postMessage({method,params:{...params,methodId}})})}
let iframeTransport;
window.addEventListener("message",event=>{if(event.origin===location.origin&&event.source===document.querySelector("iframe").contentWindow)iframeTransport=event.data.webIframeTransport});
async function report(prefix,value){await call("applog",{msg:prefix+JSON.stringify(value)})}
window.CMSCallJsMessage=function(message){if(message.method==="miniSessionChanged")report("FULL_WEB_SESSION_RESULT ",{documentNonce,method:message.method}).catch(()=>{})};
window.addEventListener("load",()=>setTimeout(async()=>{
 const checks={https:location.protocol==="https:",javascript:true,css:getComputedStyle(document.body).color==="rgb(13, 47, 83)",image:document.getElementById("pixel").naturalWidth===1};
 try{
  checks.packageName=(await call("getPackageName")).data.packageName==="com.almanac.lite";
  checks.storageSet=(await call("setStorage",{key:"web_roundtrip",data:JSON.stringify({synthetic:documentNonce})})).code==="1";
  checks.storageRead=(await call("getStorage",{key:"web_roundtrip"})).data.synthetic===documentNonce;
  checks.miniPrivilegeDenied=(await call("mini_getMiniPackageInfo")).code==="0";
  checks.iframeObserved=!!iframeTransport&&!iframeTransport.threw;
  checks.iframeDenied=(await call("getStorage",{key:"web_iframe_probe"})).code==="0";
  checks.noHostProvider=(await call("fixture_business_provider_not_installed")).code==="0";
  checks.removed=(await call("removeStorage",{key:"web_roundtrip"})).code==="1";
  const result={passed:Object.values(checks).every(Boolean),documentNonce,checks,iframeTransport};
  document.getElementById("result").textContent=result.passed?"HTTPS document verified":"Controlled check failed";
  await report("FULL_WEB_FIXTURE_RESULT ",result);
 }catch(error){report("FULL_WEB_FIXTURE_RESULT ",{passed:false,documentNonce,checks,error:String(error)}).catch(()=>{})}
},300));
