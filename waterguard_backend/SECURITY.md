# Security Guidelines

## ⚠️ Critical: Never Commit Credentials

This project uses sensitive Firebase credentials (private keys, service accounts). **NEVER commit these to version control.**

### What's Protected by `.gitignore`:

- `.env` - Contains all sensitive environment variables
- `*-firebase-adminsdk-*.json` - Firebase service account key files
- `service-account-key.json` - Service account files by any name

### If You Ever Commit Credentials:

1. **Immediately regenerate the key** in Firebase Console - the exposed key is now compromised
2. Remove the commit from git history if possible
3. Use `git filter-branch` to scrub history if needed

## Getting Firebase Credentials Safely

### 1. Generate Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (`waterguard-e1a02`)
3. Navigate to **Project Settings** (gear icon) → **Service Accounts**
4. Click **Generate New Private Key**
5. Firebase will download a JSON file (keep this file **private**)

### 2. Add to `.env`

Extract these values from the downloaded JSON and add to `.env`:

```env
FIREBASE_PROJECT_ID=waterguard-e1a02
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@waterguard-e1a02.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...(full key)...\n-----END PRIVATE KEY-----\n"
```

**Important**:

- Wrap the private key in quotes
- Preserve `\n` for line breaks in the key
- Never share this `.env` file

### 3. Verify Setup

```bash
npm run dev
# Check http://localhost:4000/health
# Check http://localhost:4000/health/firebase
```

## If You Find Exposed Credentials

If this repository or `.env` ever leaks publicly:

1. Regenerate all Firebase service account keys immediately
2. Update `.env` with new credentials
3. Consider rotating JWT_SECRET as well
4. Audit Firebase security rules and data access

## Environment Variables Checklist

Before deployment:

- [ ] `.env` is in `.gitignore`
- [ ] Never commit `.env` to git
- [ ] All credentials in `.env` are current and valid
- [ ] `JWT_SECRET` is a strong, unique value (not the dev value)
- [ ] Firebase APIs are enabled (Firestore, etc.)
- [ ] Firebase security rules are properly configured

## Development Best Practices

1. **Use `.env.example`** - Commit this with placeholder values for new developers
2. **Keep `.env` local** - Generate locally, never share via email/chat
3. **Rotate credentials periodically** - Regenerate Firebase service accounts quarterly
4. **Use different keys per environment** - Dev, staging, production keys should be different
5. **Log credential errors carefully** - Never log full keys, only partial info for debugging

## Team Onboarding

When a new developer joins:

1. Have them copy `.env.example` to `.env`
2. Provide Firebase credentials through a **secure channel** (1password, vault, etc.)
3. Never paste keys in Slack, email, or shared docs
4. Have them verify with `npm run dev`

---

**Questions?** Review Firebase Admin SDK [security documentation](https://firebase.google.com/docs/admin/setup).
