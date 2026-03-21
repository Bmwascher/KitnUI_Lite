## :kitnui: **1. Clean Slate**
* Delete or Move your old `Interface`, `WTF`, and `Fonts` folders from `_retail_`.
* Launch WoW to generate fresh folders, then **close the game**.
> *(Optional)*: Copy `Config.wtf` from your old WTF folder to the new one to restore system settings (graphics/audio).

## :kitnui: **2. Download & Install**

**Option A — All-in-One:**
* Download [**KitnUI Lite.zip**](LINK_HERE) — includes all addons, textures, and fonts.
* Unzip and move contents to your `_retail_` folder.

**Option B — Manual:**
* Download [**Textures & Fonts.zip**](LINK_HERE) and unzip.
> **`_retail_\`** — Drop the `Fonts` folder here.
> **`_retail_\Interface\`** — Drop all other folders (textures) here.
* Install addons individually via [CurseForge](https://www.curseforge.com/) or [Wago](https://addons.wago.io/).

**Required Addons** *(KitnUI Lite configures these automatically):*
> `KitnUI Lite` | `KitnEssentials` | `Ayije CDM` | `BasicMinimap` | `BigWigs` | `Chattynator` | `Details!` | `Grid2` | `Minimap Stats` | `MRT` | `Plater` | `Unhalted Unit Frames` | `WarpDeplete`
> *(You don't need all of them — KitnUI Lite will skip any that aren't installed.)*

**Recommended Addons** *(not configured by KitnUI Lite, but complement the UI):*
> `AlterEgo` | `Baganator` | `BetterCharacterPanel` | `BlizzMove` | `BugGrabber` | `BugSack` | `City Guide` | `Disintegrate Ticks` *(Evoker only)* | `Domination Socket Helper` | `FriendGroups` | `idTip` | `NoAutoClose` | `Simulationcraft` | `Syndicator` | `TrueStatValues`

**Optional — Clean Icons:**
* Download [**Clean Icons - Mechagnome Edition**](https://github.com/AcidWeb/Clean-Icons-Mechagnome-Edition/releases/tag/12.0.1.65867) and drop the `Icons` folder into `_retail_\Interface\`.
> *(Not included in the all-in-one zip due to file size. Replaces default spell/item icons with cleaner versions.)*

* **Update** all addons via Wago App or CurseForge.
> If you used the All-in-One zip, rescan your addons folder in the Wago/CurseForge app so it detects the newly added addons, then update all.

## :kitnui: **3. In-Game Setup**
* **Log in** to WoW — close any other addon popups for a clean screen. A KitnUI welcome popup will appear.
* Click **"Open Installer"** to launch the step-by-step setup.
> If you accidentally close the popup, type `/kitn install` to open it anytime.
* Walk through each page and click **Install** for each addon you want configured.
> Most addons are a single click. A few offer variants:
> • **Unit Frames (UUF):** Colored or Dark *(installs both DPS and Healer profiles)*
> • **Grid2:** Colored or Dark *(installs both DPS and Healer profiles — auto-switches per spec)*
> • **BasicMinimap / Minimap Stats:** Square or Circle

## :kitnui: **4. Blizzard Cooldown Manager**
* On the **Blizzard CDM** page, click each spec button to install its cooldown layout.
* You can return to this page anytime with `/kitn cdm`.
> *(Requires Cooldown Manager enabled in Settings > Gameplay > Combat)*

## :kitnui: **5. Done!**
* Click the **Reload UI** button on the last page of the installer, or type `/reload`, to apply everything.
* Ayije CDM and Grid2 profiles will **auto-switch** when you change specs — no manual setup needed.
> **Note:** UUF installs the correct profile for your current spec, but to enable **automatic spec switching**, open **UUF Settings > Profiles** and check **"Enable Specialization Profiles"**, then assign your DPS and Healer profiles to each spec.
> **Note:** Blizzard Edit Mode profiles do not auto-switch per spec. If you change specs, open **Edit Mode > Layouts** and manually select the **KitnUI** profile once per spec.

## :kitnui: **6. Alts (One Step)**
* Log in to your alt — a popup will ask **"Load your installed profiles?"**
* Click **Yes** — all profiles are applied automatically.
* After reload, use `/kitn cdm` to set up Blizzard CDM spec layouts.
