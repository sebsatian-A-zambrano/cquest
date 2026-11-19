/* Local browser database, with an optional SQLite mirror on this computer. */
(() => {
  const root=new URL('./',document.currentScript?.src||document.baseURI);
  let state={phase:'loading',message:'Abriendo la partida de este dispositivo…'};
  window.cquestProgressStatus=()=>JSON.stringify(state);
  window.cquestOpenSaves=()=>location.assign(new URL('partida.html',root));
  const status=(phase,message)=>{
    state={phase,message};
    window.dispatchEvent(new CustomEvent('cquest-save-state',{detail:state}));
  };
  window.cquestProgressReady=(async()=>{
    await window.cquestSqliteReady;
    const {validKey,mergeSave}=await import(new URL('save-merge.mjs',root));
    const records=new Map();
    let database=null, pending=new Map(), running=null, scheduled;
    let mirrorOK=true;
    const known=[
      'avatar','rpg.sound','rpg.crossed','campaign28.solved',
      ...['alg','c'].flatMap(lang=>Array.from({length:14},(_,i)=>[
        'rpg.world.'+lang+'-'+(i+1),'draft.'+lang+'-'+(i+1),
      ]).flat()),
    ];
    const mirrored=key=>{
      try {
        const value=localStorage.getItem('cquest.'+key);
        if(value===null)return null;
        const modifiedAt=Number(localStorage.getItem('cquest.meta.'+key))||0;
        return {key,value,modifiedAt};
      } catch (_) {mirrorOK=false;return null}
    };
    const mirror=record=>{
      try {
        localStorage.setItem('cquest.'+record.key,record.value);
        localStorage.setItem('cquest.meta.'+record.key,String(record.modifiedAt));
        return true;
      } catch (_) {mirrorOK=false;return false}
    };
    try {
      database=await new Promise((resolve,reject)=>{
        const request=indexedDB.open('cquest-partidas',1);
        request.onupgradeneeded=()=>request.result.createObjectStore('saves',{keyPath:'key'});
        request.onerror=()=>reject(request.error);
        request.onblocked=()=>reject(new Error('Database upgrade blocked'));
        request.onsuccess=()=>resolve(request.result);
      });
      const existing=await new Promise((resolve,reject)=>{
        const request=database.transaction('saves','readonly').objectStore('saves').getAll();
        request.onsuccess=()=>resolve(request.result);
        request.onerror=()=>reject(request.error);
      });
      for(const record of existing) {
        if(validKey(record.key) && typeof record.value==='string')records.set(record.key,record);
      }
    } catch (_) {database=null}
    for(const key of known) {
      const previous=mirrored(key);
      if(!previous)continue;
      const saved=records.get(key);
      if(!saved || previous.modifiedAt>saved.modifiedAt) {
        records.set(key,previous);
        pending.set(key,previous);
      }
    }
    for(const record of records.values()) window.cquestSqliteSaveProgress?.(record.key,record.value);
    async function flush() {
      if(running){await running;if(pending.size)return flush();return}
      if(!pending.size)return;
      if(!database) {
        if(mirrorOK) {pending.clear();status('saved','Partida guardada en este dispositivo')}
        else status('error','No se pudo guardar. Descarga una copia antes de cerrar.');
        return;
      }
      const batch=[...pending.values()];
      pending.clear();
      status('saving','Guardando partida…');
      running=new Promise((resolve,reject)=>{
        const tx=database.transaction('saves','readwrite');
        for(const record of batch)tx.objectStore('saves').put(record);
        tx.oncomplete=resolve;
        tx.onerror=()=>reject(tx.error);
        tx.onabort=()=>reject(tx.error);
      });
      try {
        await running;
        status('saved','Partida guardada en este dispositivo');
      } catch (_) {
        for(const record of batch) {
          if(!pending.has(record.key))pending.set(record.key,record);
        }
        status(mirrorOK?'saved':'error',mirrorOK
          ?'Partida guardada en la copia local de seguridad'
          :'No se pudo guardar. Descarga una copia antes de cerrar.');
      } finally {running=null}
    }
    function save(key,value) {
      if(!validKey(key) || typeof value!=='string' || value.length>130000)return;
      const record={key,value,modifiedAt:Date.now()};
      records.set(key,record);
      mirror(record);
      window.cquestSqliteSaveProgress?.(key,value);
      pending.set(key,record);
      status('saving','Guardando partida…');
      clearTimeout(scheduled);
      scheduled=setTimeout(()=>void flush(),0);
    }
    window.cquestReadProgress=key=>validKey(key)?records.get(key)?.value??null:null;
    window.cquestSaveProgress=save;
    window.cquestFlushProgress=flush;
    window.cquestExportProgress=async()=>{
      await flush();
      return JSON.stringify({
        game:'CQuest',version:1,exportedAt:new Date().toISOString(),
        saves:[...records.values()],
      },null,2);
    };
    window.cquestImportProgress=async text=>{
      if(typeof text!=='string' || text.length>8000000)throw new Error('La copia es demasiado grande.');
      let backup;
      try{backup=JSON.parse(text)}catch(_){throw new Error('El archivo no contiene una copia válida.')}
      if(backup?.game!=='CQuest' || backup.version!==1 || !Array.isArray(backup.saves) || backup.saves.length>64)
        throw new Error('El archivo no es una copia de CQuest compatible.');
      const checked=backup.saves.map(record=>{
        if(!record || !validKey(record.key) || typeof record.value!=='string' ||
          record.value.length>130000 || !Number.isSafeInteger(record.modifiedAt) || record.modifiedAt<0)
          throw new Error('La copia contiene datos inválidos.');
        return record;
      });
      // Validate the whole file before changing a single entry.
      for(const record of checked) {
        const merged=mergeSave(record.key,records.get(record.key),record);
        save(record.key,merged.value);
      }
      await flush();
      return checked.length;
    };
    window.cquestSaveSummary=()=>{
      const raw=records.get('rpg.crossed')?.value||'';
      const count=new Set(raw.split(',').filter(x=>/^\d+$/.test(x)&&Number(x)<28)).size;
      return {chapters:count,entries:records.size,database:Boolean(database)};
    };
    window.addEventListener('pagehide',()=>void flush());
    document.addEventListener('visibilitychange',()=>{if(document.hidden)void flush()});
    if(pending.size)await flush();
    else status(database||mirrorOK?'saved':'error',database||mirrorOK
      ?'Partida guardada en este dispositivo':'El navegador bloquea el guardado. Descarga una copia antes de cerrar.');
  })().catch(()=>{
    status('error','No se pudo abrir la partida. Recarga el juego.');
  });
})();
