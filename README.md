# GANB FE Workshop Register

This is the fire extinguisher workshop app, hosted on Cloudflare Pages, with its data in Supabase.

| File | What it is |
|---|---|
| `index.html` | The app |
| `ganb-logo.jpg` | GANB logo, used on the sign-in screen, in the header and on PDFs |
| `supabase-setup.sql` | Database setup. Run it once in Supabase |

## One-time setup

### 1. Supabase: create the database
1. Open your project at supabase.com, then **SQL Editor → New query**.
2. Paste all of `supabase-setup.sql` and click **Run**. You should see "Success".
3. Go to **Authentication → Sign In / Providers → Email** and turn **off** "Allow new users to sign up". This way only the administrator creates logins.

### 2. Supabase: create the logins
For each person, open **Authentication → Users → Add user → Create new user**:
- Enter their email and a starting password (8+ characters).
- Turn **Auto Confirm User** on.

The first users are:

| Name | Email | Role |
|---|---|---|
| Carlos Rodriguez | crodriguez@ganb.com | Administrator |
| Inemar Lopez | contact@ganbglobal.com | Office |
| David Croes | service4aua@ganb.com | Technician |

Each person can change their own password later in the app under **Settings → Your account**.

### 3. GitHub: upload the files
1. On github.com, click **New repository**.
2. Name it `ganb-workshop`, select **Private**, and click **Create repository**.
3. Click **uploading an existing file**, drag in all the files from this folder, then click **Commit changes**.

### 4. Cloudflare: publish the app
1. In the Cloudflare dashboard, go to **Workers & Pages → Create → Pages → Connect to Git**.
2. Choose the `ganb-workshop` repository.
3. Set these build settings:
   - Project name: `ganb-workshop`
   - Framework preset: **None**
   - Build command: leave it empty
   - Build output directory: `/`
4. Click **Save and Deploy**. The app is then live at `https://ganb-workshop.pages.dev`. If that name is taken, Cloudflare adds a few characters to it.

### 5. Move the records from the old Claude app
1. In the **old** app (in Claude), open **Settings → Download backup (Excel)**.
2. In the **new** app, sign in as Carlos and go to **Settings → Restore from backup**.
3. Choose that Excel file. Clients, extinguishers, delivery notes, company details and the number counters are all brought over.

Make this the last change in the old app, then stop using it, so that records don't end up split between the two.

## Updating the app later
To change the app, replace `index.html` in the GitHub repository (**Add file → Upload files**). Cloudflare publishes the new version in about a minute. The data in Supabase is not affected.

## Adding a person later
1. In the app, go to **Settings → Users → Add user** and enter their name, email and role.
2. In Supabase, create their login as in step 2.

To remove someone's access immediately, untick **Active** for that person.

## Who can do what
| Action | Administrator | Office | Technician |
|---|:-:|:-:|:-:|
| Register intake, add a new client from intake | ✓ | ✓ | ✓ |
| Record service work on units still in the workshop | ✓ | ✓ | ✓ |
| Change units that were already delivered | ✓ | ✓ | – |
| Create delivery notes | ✓ | ✓ | – |
| Edit clients | ✓ | ✓ | – |
| Delete records or clients, cancel delivery notes | ✓ | – | – |
| Company details, users, backup and restore, activity log | ✓ | – | – |

These rules are enforced by the database itself, not only by the screens.

## Backups
The Supabase free plan has no automatic backups. Once a week, the administrator should run **Settings → Download backup (Excel)** and keep the file somewhere safe. The app reminds you when a backup is due.

## Custom web address (optional, later)
1. In Cloudflare Pages, open the project and go to **Custom domains → Set up a domain** and enter `workshop.ganbglobal.com`.
2. Whoever manages ganbglobal.com adds the **CNAME** record that Cloudflare shows (`workshop` → `ganb-workshop.pages.dev`).
