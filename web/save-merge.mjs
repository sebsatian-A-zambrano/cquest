export function validKey(key) {
  return key === 'avatar' || key === 'rpg.sound' ||
    ['rpg.crossed', 'campaign28.solved'].includes(key) ||
    /^rpg\.world\.(alg|c)-(?:[1-9]|1[0-4])$/.test(key) ||
    /^draft\.(alg|c)-(?:[1-9]|1[0-4])$/.test(key);
}

export function mergeSave(key, remote, local) {
  if (!remote) return {value:local.value, modifiedAt:local.modifiedAt};
  const newest = local.modifiedAt >= remote.modifiedAt ? local : remote;
  let value = newest.value;
  if (key === 'rpg.crossed' || key === 'campaign28.solved') {
    value = [...new Set((remote.value+','+local.value).split(',')
      .filter(v => /^\d+$/.test(v)).map(Number).filter(v => v>=0 && v<28))]
      .sort((a,b) => a-b).join(',');
  } else if (key.startsWith('rpg.world.')) {
    try {
      const a=JSON.parse(remote.value), b=JSON.parse(local.value);
      const chosen = newest===local ? b : a;
      value = JSON.stringify({
        ...chosen,
        charged:a.charged===true || b.charged===true,
        memory:a.memory===true || b.memory===true,
        repaired:a.repaired===true || b.repaired===true,
        finished:a.finished===true || b.finished===true,
      });
    } catch (_) {
      // Invalid older saves cannot prevent a newer valid save.
    }
  }
  return {value, modifiedAt:Math.max(remote.modifiedAt,local.modifiedAt)};
}
