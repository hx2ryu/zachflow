const assert = require('node:assert');
const { greet } = require('./index');

assert.strictEqual(greet('world'), 'hello, world');
console.log('demo test OK');
