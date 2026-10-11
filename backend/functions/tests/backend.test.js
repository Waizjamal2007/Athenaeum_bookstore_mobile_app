const {test, beforeEach} = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');
let state, users, sent, calls;
const clone = (x) => x == null ? null : structuredClone(x);
const read = (path) => path.split('/').filter(Boolean).reduce((x, k) => x?.[k], state);
function write(path, value) {
  const keys = path.split('/').filter(Boolean);
  if (!keys.length) {state = clone(value); return;}
  let node = state;
  for (const k of keys.slice(0, -1)) node = node[k] ||= {};
  if (value === null) delete node[keys.at(-1)]; else node[keys.at(-1)] = clone(value);
}
function snapshot(value) {return {val: () => clone(value), exists: () => value != null};}
const db = {ref(path = '') {return {
  key: path.split('/').at(-1),
  push() {return db.ref(`${path}/id${++calls}`);},
  async get() {return snapshot(read(path));},
  async set(v) {write(path, v);},
  async remove() {write(path, null);},
  async update(values) {for (const [k, v] of Object.entries(values)) write(path ? `${path}/${k}` : k, v);},
  async transaction(fn) {
    const result = fn(clone(read(path)));
    if (result !== undefined) write(path, result);
    return {committed: result !== undefined, snapshot: snapshot(read(path))};
  },
};}};
class HttpsError extends Error {constructor(code, message) {super(message); this.code = code;}}
const auth = {
  async getUser(uid) {if (!users[uid]) {const e = Error('Not found'); e.code = 'auth/user-not-found'; throw e;} return clone(users[uid]);},
  async updateUser(uid, data) {Object.assign(users[uid], data);},
  async revokeRefreshTokens(uid) {users[uid].revoked = true;},
  async deleteUser(uid) {delete users[uid];},
};
const load = Module._load;
Module._load = function(name, ...args) {
  if (name === 'firebase-functions/v2/https') return {HttpsError, onCall: (_, fn) => fn};
  if (name === 'firebase-functions/v2/database') return {
    onValueWritten: (_, fn) => fn, onValueCreated: (_, fn) => fn, onValueUpdated: (_, fn) => fn};
  if (name === 'firebase-admin/app') return {initializeApp() {}};
  if (name === 'firebase-admin/auth') return {getAuth: () => auth};
  if (name === 'firebase-admin/database') return {getDatabase: () => db};
  if (name === 'firebase-admin/messaging') return {getMessaging: () => ({
    async send(message) {sent.push(message); return 'message';},
    async sendEachForMulticast(message) {sent.push(message); return {responses: message.tokens.map(() => ({success: true}))};},
  })};
  return load.call(this, name, ...args);
};
const api = require('../index.js');
Module._load = load;
const req = (uid, data) => ({auth: {uid}, data});
beforeEach(() => {
  calls = 0; sent = [];
  users = {reader: {uid: 'reader', emailVerified: true, disabled: false},
    admin: {uid: 'admin', emailVerified: true, customClaims: {admin: true}}};
  state = {books: {book: {title: 'Book', author: 'Author', price: 19.99, stock: 5}},
    users: {reader: {name: 'Reader'}}, carts: {reader: {book: 2}}};
});
test('checkout uses catalog prices and authenticated user, applies tax and reserves stock', async () => {
  const result = await api.createOrder(req('reader', {userId: 'attacker', total: 1,
    items: [{bookId: 'book', qty: 2, price: 0.01}]}));
  const order = state.orders[result.orderId];
  assert.equal(order.userId, 'reader'); assert.equal(order.subtotal, 39.98);
  assert.equal(order.tax, 3.2); assert.equal(order.total, 43.18);
  assert.equal(state.books.book.stock, 3); assert.equal(state.carts.reader, undefined);
});
test('out of stock rejects without altering cart, stock or orders', async () => {
  const initial = clone(state);
  await assert.rejects(api.createOrder(req('reader', {items: [{bookId: 'book', qty: 6}]})), {code: 'failed-precondition'});
  assert.deepEqual(state, initial);
});
test('negative quantities and duplicate books reject', async () => {
  await assert.rejects(api.createOrder(req('reader', {items: [{bookId: 'book', qty: -1}]})), {code: 'invalid-argument'});
  await assert.rejects(api.createOrder(req('reader', {items: [{bookId: 'book', qty: 1}, {bookId: 'book', qty: 1}]})), {code: 'invalid-argument'});
});
test('reader cannot manage accounts or broadcast announcements', async () => {
  await assert.rejects(api.manageUser(req('reader', {uid: 'reader', action: 'disable'})), {code: 'permission-denied'});
  await assert.rejects(api.sendAnnouncement(req('reader', {title: 'Spam', body: 'Spam'})), {code: 'permission-denied'});
});
test('disabled and unverified users cannot checkout', async () => {
  users.reader.disabled = true;
  await assert.rejects(api.createOrder(req('reader', {items: [{bookId: 'book', qty: 1}]})), {code: 'permission-denied'});
  users.reader.disabled = false; users.reader.emailVerified = false;
  await assert.rejects(api.createOrder(req('reader', {items: [{bookId: 'book', qty: 1}]})), {code: 'permission-denied'});
});
test('admin disables real Auth account and revokes sessions; cannot disable self', async () => {
  await api.manageUser(req('admin', {uid: 'reader', action: 'disable'}));
  assert.equal(users.reader.disabled, true); assert.equal(users.reader.revoked, true);
  assert.equal(state.users.reader.disabled, true);
  await assert.rejects(api.manageUser(req('admin', {uid: 'admin', action: 'disable'})), {code: 'permission-denied'});
});
test('admin edits both display name and DB profile', async () => {
  await api.manageUser(req('admin', {uid: 'reader', action: 'edit', name: 'New Name', shippingAddress: 'Karachi', paymentMethod: 'COD'}));
  assert.equal(users.reader.displayName, 'New Name'); assert.equal(state.users.reader.name, 'New Name');
});
test('admin deletes Auth account and private records while preserving orders', async () => {
  state.orders = {old: {userId: 'reader'}}; state.deviceTokens = {reader: {token: {}}};
  await api.manageUser(req('admin', {uid: 'reader', action: 'delete'}));
  assert.equal(users.reader, undefined); assert.equal(state.users.reader, undefined);
  assert.equal(state.carts.reader, undefined); assert.equal(state.deviceTokens.reader, undefined);
  assert.ok(state.orders.old);
});
test('catalog stock-only changes do not notify; author/title updates produce inbox record', async () => {
  const before = clone(state.books.book), after = {...before, stock: 4};
  await api.onBookChanged({id: 'event1', params: {bookId: 'book'}, data: {before: snapshot(before), after: snapshot(after)}});
  assert.equal(state.announcements, undefined);
  after.author = 'New Author';
  await api.onBookChanged({id: 'event2', params: {bookId: 'book'}, data: {before: snapshot(before), after: snapshot(after)}});
  assert.match(Object.values(state.announcements)[0].body, /New Author/);
});
test('order notifications target only owner devices, with notification payload', async () => {
  state.deviceTokens = {reader: {ownToken: {}}, another: {otherToken: {}}};
  await api.onOrderCreated({id: 'event3', params: {orderId: 'order1'}, data: snapshot({userId: 'reader', status: 'Placed'})});
  assert.deepEqual(sent[0].tokens, ['ownToken']); assert.equal(sent[0].notification.title, 'Order update');
  assert.equal(sent[0].android.notification.channelId, 'athenaeum_updates');
  assert.equal(sent[0].data.userId, 'reader'); assert.ok(state.notifications.reader);
});
test('review likes are deduplicated per authenticated account', async () => {
  state.reviews = {book: {review: {likes: 0, text: 'Good'}}};
  await api.likeReview(req('reader', {bookId: 'book', reviewId: 'review'}));
  await api.likeReview(req('reader', {bookId: 'book', reviewId: 'review'}));
  assert.equal(state.reviews.book.review.likes, 1);
});
