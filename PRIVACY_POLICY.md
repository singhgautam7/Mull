# Privacy Policy for Mull

**Last Updated:** September 20, 2026

**Developer:** Gautam Rajeev Singh
**Application:** Mull — Offline English Dictionary and Vocabulary

---

## 1. Overview & Core Philosophy

Mull is designed from the ground up to be **offline, calm, and private**. The dictionary ships inside the app, and everything you do with it (bookmarks, shelves, notes, the words you have seen) stays on your device.

- **No Account Required:** You do not need to register, sign in, or create an account to use Mull.
- **No Network Access:** Mull declares no internet permission. It makes no network request, ever: not to look up a word, not to update the dictionary, not to report anything.
- **No Analytics, Tracking, or Ads:** Mull contains zero third-party advertising SDKs, tracking tools, or telemetry.

---

## 2. Information Collected and Stored

### Local Storage on Your Device
All data created in Mull is stored entirely on your device in a private local database. This includes:
- Bookmarks, shelves and the words on them
- Personal notes on words
- Sentences you sent to Mull from other apps (the "you met this in" context), with the name of the app they came from
- Which words you have seen, and when, for spaced repetition and the Stats screen
- Quiz sessions and answers
- Application preferences (theme, text size, spelling, word-of-the-day time)

This data never leaves your device unless you explicitly use the export feature.

### Text sent from other apps
When you choose "Define in Mull" from another app's text selection menu, or share text to Mull, the selected text is handed to Mull by Android and used only to open the matching entry. If you choose to keep the sentence, it is stored locally alongside the word. It is never transmitted anywhere.

### Data We Do NOT Collect
- We do not collect personally identifiable information (PII) such as your name, email address, physical address, or phone number.
- We do not track your location, usage statistics, or the words you look up.
- Nothing is uploaded, synced or backed up by Mull itself. Android's own backup service may include Mull's local database in your device backup according to your Android settings.

---

## 3. Network Usage & Device Permissions

Mull requires minimal device permissions to function as intended:

| Permission | Purpose |
| :--- | :--- |
| `android.permission.POST_NOTIFICATIONS` | Only if you turn on the word-of-the-day reminder: one local notification a day at the time you chose. Nothing else will ever notify you. |
| `android.permission.RECEIVE_BOOT_COMPLETED` | Re-arms that daily reminder after the device restarts. |

Mull does **not** request the `INTERNET` permission. The notification and the launcher widget are built from the dictionary already on your device.

---

## 4. Third-Party Services and SDKs

Mull does not integrate with any third-party analytics (e.g., Google Analytics, Firebase Analytics), advertising networks, or data brokers.

Pronunciation uses the text-to-speech engine installed on your device (for example Google Text-to-speech). That engine runs under its own privacy policy; Mull sends it only the word to be spoken.

The dictionary text is derived from Wiktionary via Kaikki.org (CC BY-SA 4.0), Open English WordNet (CC BY 4.0), and published word-frequency and word-rating datasets; attribution is shown in the app under More → Dictionary.

---

## 5. Data Ownership, Export, and Deletion

- **Export:** You can export your shelves, notes and mixes at any time from the Data screen as JSON, and any shelf as CSV or PDF.
- **Deletion:** You have full control over your data. You can delete individual notes, shelves, words and seen history at any time, or reset everything from the Data screen. Uninstalling the app permanently removes all locally stored files.

---

## 6. Children's Privacy

Mull does not collect, solicit, or store personal information from anyone, including children under the age of 13 (or under 16 in certain jurisdictions).

---

## 7. Changes to This Privacy Policy

If this Privacy Policy is updated in the future, the revised version will be published here with an updated "Last Updated" date.

---

## 8. Contact Information

If you have any questions, feedback, or concerns regarding this Privacy Policy or Mull, please contact:

**Developer:** Gautam Rajeev Singh
**Project:** Mull
