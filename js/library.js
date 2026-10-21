// Persists books (metadata + bookmarks) and their audio blobs in IndexedDB,
// so files picked once are available every night without re-selecting them.

const DB_NAME = 'audiobook-to-sleep';
const DB_VERSION = 1;

let dbPromise = null;

function openDb() {
  dbPromise ??= new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      db.createObjectStore('books', { keyPath: 'id' });
      db.createObjectStore('files');
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
  return dbPromise;
}

async function run(storeNames, mode, fn) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeNames, mode);
    let result;
    Promise.resolve(fn(tx)).then((r) => { result = r; }, reject);
    tx.oncomplete = () => resolve(result);
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error);
  });
}

const request = (req) => new Promise((resolve, reject) => {
  req.onsuccess = () => resolve(req.result);
  req.onerror = () => reject(req.error);
});

function probeDuration(blob) {
  return new Promise((resolve) => {
    const audio = new Audio();
    const url = URL.createObjectURL(blob);
    const done = (value) => { URL.revokeObjectURL(url); resolve(value); };
    audio.preload = 'metadata';
    audio.onloadedmetadata = () => done(Number.isFinite(audio.duration) ? audio.duration : 0);
    audio.onerror = () => done(0);
    audio.src = url;
  });
}

function guessTitle(files) {
  const name = files[0].name.replace(/\.[^.]+$/, '');
  if (files.length === 1) return name;
  // Strip trailing track numbers like "Book - 01" or "Book_Part1".
  return name.replace(/[\s_\-.]*(part|chapter|track|cd|disc)?[\s_\-.]*\d+$/i, '') || name;
}

export async function listBooks() {
  const books = await run(['books'], 'readonly', (tx) => request(tx.objectStore('books').getAll()));
  return books.sort((a, b) => (b.lastPlayedAt ?? b.addedAt) - (a.lastPlayedAt ?? a.addedAt));
}

export async function getBook(id) {
  return run(['books'], 'readonly', (tx) => request(tx.objectStore('books').get(id)));
}

export async function saveBook(book) {
  return run(['books'], 'readwrite', (tx) => request(tx.objectStore('books').put(book)));
}

export async function getTrackBlob(bookId, index) {
  return run(['files'], 'readonly', (tx) => request(tx.objectStore('files').get(`${bookId}:${index}`)));
}

export async function addBook(fileList) {
  const files = [...fileList].sort((a, b) =>
    a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: 'base' }));
  if (files.length === 0) throw new Error('No files selected');

  const durations = await Promise.all(files.map(probeDuration));
  const book = {
    id: crypto.randomUUID(),
    title: guessTitle(files),
    tracks: files.map((f, i) => ({ name: f.name, duration: durations[i] })),
    position: 0,
    addedAt: Date.now(),
    lastPlayedAt: null,
    nights: [],
  };

  await run(['books', 'files'], 'readwrite', (tx) => {
    const store = tx.objectStore('files');
    files.forEach((f, i) => store.put(f, `${book.id}:${i}`));
    tx.objectStore('books').put(book);
  });
  navigator.storage?.persist?.();
  return book;
}

export async function deleteBook(book) {
  return run(['books', 'files'], 'readwrite', (tx) => {
    tx.objectStore('books').delete(book.id);
    book.tracks.forEach((_, i) => tx.objectStore('files').delete(`${book.id}:${i}`));
  });
}
