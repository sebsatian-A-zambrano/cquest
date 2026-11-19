import assert from 'node:assert/strict';
import {test} from 'node:test';
import {mergeSave,validKey} from '../web/save-merge.mjs';

test('a slower device cannot remove a completed chapter',()=>{
 const saved=mergeSave('rpg.crossed',{value:'0,1',modifiedAt:50},{value:'0,14',modifiedAt:10});
 assert.equal(saved.value,'0,1,14');
});
test('repair and optional memories survive saving from another device',()=>{
 const old={value:JSON.stringify({choice:0,repaired:true,memory:false}),modifiedAt:10};
 const next={value:JSON.stringify({choice:1,repaired:false,memory:true}),modifiedAt:20};
 const value=JSON.parse(mergeSave('rpg.world.alg-1',old,next).value);
 assert.equal(value.repaired,true);assert.equal(value.memory,true);assert.equal(value.choice,1);
});
test('newer drafts win and arbitrary storage keys are rejected',()=>{
 assert.equal(mergeSave('draft.c-1',{value:'old',modifiedAt:2},{value:'new',modifiedAt:3}).value,'new');
 assert.equal(validKey('rpg.world.c-14'),true);
 assert.equal(validKey('rpg.world.c-15'),false);
 assert.equal(validKey('auth.token'),false);
});
