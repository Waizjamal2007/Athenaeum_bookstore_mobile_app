'use strict';
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onValueWritten, onValueCreated, onValueUpdated} = require('firebase-functions/v2/database');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getDatabase} = require('firebase-admin/database');
const {getMessaging} = require('firebase-admin/messaging');
initializeApp({databaseURL: 'https://athenaeum-8845d-default-rtdb.firebaseio.com'});
const db = getDatabase();
const region = 'us-central1';
const trigger = (ref) => ({ref, region, instance: 'athenaeum-8845d-default-rtdb', retry: true});
const topic = 'athenaeum_readers';
const key = (value) => typeof value === 'string' && value.length > 0 &&
  value.length <= 200 && !/[.#$\[\]/]/.test(value);
const clean = (value, max, label) => {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max) {
    throw new HttpsError('invalid-argument', `${label} is required (maximum ${max} characters).`);
  }
  return value.trim();
};
async function active(request, adminOnly = false) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
  const user = await getAuth().getUser(request.auth.uid);
  if (user.disabled || !user.emailVerified) throw new HttpsError('permission-denied', 'Verify your email and use an active account.');
  if (adminOnly && user.customClaims?.admin !== true) {
    throw new HttpsError('permission-denied', 'Administrator access required.');
  }
  return user;
}
function payload(title, body, data) {
  return {notification: {title, body}, data,
    android: {priority: 'high', ttl: 24 * 60 * 60 * 1000,
      notification: {channelId: 'athenaeum_updates', icon: 'ic_stat_book', sound: 'default'}},
    apns: {headers: {'apns-priority': '10'}, payload: {aps: {sound: 'default'}}}};
}
async function sendPrivate(uid, title, body, data) {
  const user = await getAuth().getUser(uid).catch((e) => {
    if (e.code === 'auth/user-not-found') return null;
    throw e;
  });
  if (!user || user.disabled) return;
  const tokens = Object.keys((await db.ref(`deviceTokens/${uid}`).get()).val() || {});
  for (let i = 0; i < tokens.length; i += 500) {
    const chunk = tokens.slice(i, i + 500);
    const result = await getMessaging().sendEachForMulticast({tokens: chunk, ...payload(title, body, data)});
    let retry = false;
    for (let j = 0; j < result.responses.length; j++) {
      const response = result.responses[j];
      if (!response.success) {
        const code = response.error?.code;
        if (['messaging/invalid-registration-token', 'messaging/registration-token-not-registered'].includes(code)) {
          await db.ref(`deviceTokens/${uid}/${chunk[j]}`).remove();
        } else { retry = true; }
      }
    }
    if (retry) throw new Error('Transient push delivery failure; trigger will retry.');
  }
}
exports.manageUser = onCall({region}, async (request) => {
  const admin = await active(request, true);
  const {uid, action} = request.data || {};
  if (!key(uid) || !['edit', 'disable', 'enable', 'delete'].includes(action)) {
    throw new HttpsError('invalid-argument', 'Invalid user or action.');
  }
  const target = await getAuth().getUser(uid);
  if (uid === admin.uid || target.customClaims?.admin === true) {
    throw new HttpsError('permission-denied', 'Manage administrator accounts from the trusted setup script or Firebase Console.');
  }
  if (action === 'edit') {
    const name = clean(request.data.name, 80, 'Name');
    const shippingAddress = String(request.data.shippingAddress ?? '').trim();
    const paymentMethod = String(request.data.paymentMethod ?? '').trim();
    if (shippingAddress.length > 500 || paymentMethod.length > 100) {
      throw new HttpsError('invalid-argument', 'Address or payment preference is too long.');
    }
    await getAuth().updateUser(uid, {displayName: name});
    await db.ref(`users/${uid}`).update({name, shippingAddress, paymentMethod, updatedAt: Date.now()});
  } else if (action === 'delete') {
    await getAuth().deleteUser(uid);
    await db.ref().update({[`users/${uid}`]: null, [`carts/${uid}`]: null,
      [`wishlists/${uid}`]: null, [`deviceTokens/${uid}`]: null, [`notifications/${uid}`]: null});
  } else {
    const disabled = action === 'disable';
    // Record database status first so rules immediately reject an active session.
    await db.ref(`users/${uid}`).update({disabled, updatedAt: Date.now()});
    await getAuth().updateUser(uid, {disabled});
    if (disabled) await getAuth().revokeRefreshTokens(uid);
  }
  return {success: true};
});
exports.sendAnnouncement = onCall({region}, async (request) => {
  await active(request, true);
  const title = clean(request.data?.title, 100, 'Title');
  const body = clean(request.data?.body, 500, 'Message');
  const ref = db.ref('announcements').push();
  await ref.set({title, body, type: 'announcement', createdAt: Date.now()});
  return {id: ref.key};
});
exports.onAnnouncement = onValueCreated(trigger('/announcements/{id}'), async (event) => {
  const row = event.data.val();
  await getMessaging().send({topic, ...payload(row.title, row.body,
    {type: row.type || 'announcement', bookId: row.bookId || '', notificationId: event.params.id})});
});
exports.onBookChanged = onValueWritten(trigger('/books/{bookId}'), async (event) => {
  const before = event.data.before.val(), after = event.data.after.val();
  const watched = ['title', 'author', 'genre', 'description', 'price', 'year', 'bestseller', 'newArrival', 'imageUrl'];
  // Stock-only checkout changes should not broadcast a catalog update.
  if (before && after && watched.every((k) => before[k] === after[k])) return;
  const book = after || before;
  if (!book || book.suppressNotification === true) return;
  const title = !before ? 'New book added' : !after ? 'Catalog update' : 'Book updated';
  const body = !after ? `${book.title} has been removed from the catalog.` : `${book.title} by ${book.author}`;
  // Stable event key makes the inbox write idempotent on trigger retry.
  const id = Buffer.from(event.id).toString('base64url');
  await db.ref(`announcements/${id}`).set({title, body, type: 'book',
    bookId: event.params.bookId, createdAt: Date.now()});
});
async function orderMessage(order, orderId, eventId) {
  if (!key(order?.userId)) return;
  const title = 'Order update';
  const body = `Order ${orderId}: ${order.status || 'Placed'}`;
  const id = Buffer.from(eventId).toString('base64url');
  await db.ref(`notifications/${order.userId}/${id}`).set({title, body,
    type: 'order', orderId, createdAt: Date.now()});
  await sendPrivate(order.userId, title, body, {type: 'order', orderId, userId: order.userId});
}
exports.onOrderCreated = onValueCreated(trigger('/orders/{orderId}'), (event) =>
  orderMessage(event.data.val(), event.params.orderId, event.id));
exports.onOrderUpdated = onValueUpdated(trigger('/orders/{orderId}'), async (event) => {
  const before = event.data.before.val(), after = event.data.after.val();
  if (before.status !== after.status) await orderMessage(after, event.params.orderId, event.id);
});
exports.createOrder = onCall({region}, async (request) => {
  const user = await active(request);
  const input = request.data?.items;
  if (!Array.isArray(input) || input.length === 0 || input.length > 100) {
    throw new HttpsError('invalid-argument', 'Choose 1 to 100 books.');
  }
  const selected = new Map();
  for (const item of input) {
    if (!key(item.bookId) || !Number.isInteger(item.qty) || item.qty < 1 || item.qty > 100) {
      throw new HttpsError('invalid-argument', 'Invalid book or quantity.');
    }
    if (selected.has(item.bookId)) throw new HttpsError('invalid-argument', 'Duplicate book.');
    selected.set(item.bookId, item.qty);
  }
  const orderId = db.ref('orders').push().key;
  let problem = 'Please retry checkout.';
  let order;
  // A single transaction atomically reserves stock, writes the order and clears cart.
  // This uses a root transaction for this small eProject. At scale, move checkout
  // to a dedicated inventory/order service to avoid whole-database contention.
  const result = await db.ref().transaction((root) => {
    if (!root) return {};
    if (!root.users?.[user.uid] || root.users[user.uid].disabled === true) {
      problem = 'Your profile is unavailable or disabled.'; return;
    }
    let subtotal = 0;
    const items = [];
    for (const [bookId, qty] of selected) {
      const book = root.books?.[bookId];
      if (!book || !Number.isInteger(book.stock) || book.stock < qty) {
        problem = `${book?.title || bookId} is unavailable or has insufficient stock.`; return;
      }
      if (typeof book.price !== 'number' || !Number.isFinite(book.price) || book.price < 0) {
        problem = 'Invalid catalog price. Contact the store.'; return;
      }
      subtotal += Math.round(book.price * 100) * qty;
      items.push({bookId, qty, title: book.title, author: book.author, price: book.price});
    }
    const tax = Math.round(subtotal * 0.08);
    order = {userId: user.uid, items, subtotal: subtotal / 100, tax: tax / 100,
      total: (subtotal + tax) / 100, status: 'Placed', createdAt: Date.now()};
    for (const [bookId, qty] of selected) root.books[bookId].stock -= qty;
    root.orders ||= {}; root.orders[orderId] = order;
    if (root.carts) delete root.carts[user.uid];
    return root;
  });
  if (!result.committed || !order) throw new HttpsError('failed-precondition', problem);
  return {orderId, total: order.total};
});
exports.likeReview = onCall({region}, async (request) => {
  const user = await active(request);
  const {bookId, reviewId} = request.data || {};
  if (!key(bookId) || !key(reviewId)) throw new HttpsError('invalid-argument', 'Invalid review.');
  const result = await db.ref(`reviews/${bookId}/${reviewId}`).transaction((review) => {
    if (!review) return review;
    review.likedBy ||= {};
    if (!review.likedBy[user.uid]) {
      review.likedBy[user.uid] = true;
      review.likes = (Number(review.likes) || 0) + 1;
    }
    return review;
  });
  if (!result.snapshot.exists()) throw new HttpsError('not-found', 'Review no longer exists.');
  return {success: true};
});
