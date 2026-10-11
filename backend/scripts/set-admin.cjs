// Run from backend/functions after npm install: node ../scripts/set-admin.cjs EMAIL
const {createRequire} = require('node:module');
const fromFunctions = createRequire(require('node:path').resolve(__dirname, '../functions/package.json'));
const {initializeApp, applicationDefault} = fromFunctions('firebase-admin/app');
const {getAuth} = fromFunctions('firebase-admin/auth');
const {getDatabase} = fromFunctions('firebase-admin/database');
initializeApp({credential: applicationDefault(), databaseURL: 'https://athenaeum-8845d-default-rtdb.firebaseio.com'});
(async () => {
  const email = process.argv[2];
  if (!email) throw new Error('Usage: node ../scripts/set-admin.cjs EMAIL');
  const user = await getAuth().getUserByEmail(email);
  // Verify this account's mailbox normally before running this script.
  if (!user.emailVerified) throw new Error('Verify the admin email first.');
  await getAuth().setCustomUserClaims(user.uid, {...user.customClaims, admin: true});
  await getDatabase().ref(`users/${user.uid}`).update({name: user.displayName || 'Administrator', email: user.email, disabled: false});
  console.log('Admin role assigned. Sign out and sign in again.');
})().catch((error) => {console.error(error.message); process.exitCode = 1;});
