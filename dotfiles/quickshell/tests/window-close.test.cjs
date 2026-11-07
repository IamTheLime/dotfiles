const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { test } = require('node:test');
const source = fs.readFileSync(`${__dirname}/../desktop/platform/kde/kwin-close.js`, 'utf8');

test('should close only requested closeable windows and tolerate windows already closed', () => {
    const closed = [];
    const windows = ['one', 'two', 'other', 'protected'].map(id => ({
        internalId: id, closeable: id !== 'protected', closeWindow: () => closed.push(id)
    }));
    vm.runInNewContext(source, {ids: ['one', 'missing', 'protected'], workspace: {windowList: () => windows}});
    assert.deepEqual(closed, ['one']);
});

test('should recheck each window when closing one also closes another', () => {
    const closed = [];
    let windows = ['one', 'two', 'three'].map(id => ({
        internalId: id, closeable: true, closeWindow: () => {
            closed.push(id);
            if (id === 'one') windows = windows.filter(w => w.internalId === 'three');
        }
    }));
    vm.runInNewContext(source, {ids: ['one', 'two', 'three'], workspace: {windowList: () => windows}});
    assert.deepEqual(closed, ['one', 'three']);
});
