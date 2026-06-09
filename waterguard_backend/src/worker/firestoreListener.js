const { getFirestore } = require("../firebase");
const { ingestEsp32LiveData } = require("../db");

function startFirestoreListener() {
  const firestore = getFirestore();
  const colRef = firestore.collection("raw_esp32");

  console.log("Starting Firestore listener for collection: raw_esp32");

  colRef.onSnapshot(
    (snapshot) => {
      snapshot.docChanges().forEach((change) => {
        if (change.type !== "added") return;

        (async () => {
          const doc = change.doc;
          const data = doc.data() || {};

          // skip already-processed docs
          if (data._processed) return;

          try {
            console.log(`Processing raw_esp32 doc ${doc.id}`);
            const result = await ingestEsp32LiveData(data);

            await doc.ref.set(
              {
                _processed: true,
                _processedAt: new Date().toISOString(),
                _processingResult: result,
              },
              { merge: true },
            );

            console.log(`Processed raw_esp32 doc ${doc.id} successfully`);
          } catch (err) {
            console.error(`Error processing raw_esp32 doc ${doc.id}:`, err);
            try {
              await doc.ref.set(
                {
                  _processed: false,
                  _processedAt: new Date().toISOString(),
                  _processingError: String(err.message || err),
                },
                { merge: true },
              );
            } catch (e) {
              console.error("Failed to write processing error to doc", e);
            }
          }
        })();
      });
    },
    (err) => {
      console.error("Firestore listener error on raw_esp32 collection:", err);
    },
  );
}

module.exports = { startFirestoreListener };
