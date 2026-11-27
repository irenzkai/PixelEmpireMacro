//! The `rbxcache` subcommands, and the entry description shared with the window.

use crate::config::{self, IdMap};
use crate::format::{self, human_size};
use crate::store::{self, category_name, format_time_ms, Entry, Store};
use crate::viewers::View;
use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand, ValueEnum};
use std::cmp::Reverse;
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[derive(Parser)]
#[command(
    name = "rbxcache",
    version,
    about = "Explore, export, replace and delete entries of the Roblox asset cache.\nRun without a command to open the window."
)]
pub struct Args {
    /// Folder holding rbx-storage.db [default: the Roblox client's own folder]
    #[arg(long, global = true)]
    pub dir: Option<PathBuf>,
    /// Asset ID map file [default: idmap.json in the app's data folder]
    #[arg(long, global = true)]
    pub idmap: Option<PathBuf>,
    #[command(subcommand)]
    pub cmd: Option<Cmd>,
}

#[derive(Subcommand)]
pub enum Cmd {
    /// Open the graphical explorer (the default)
    Gui {
        /// Open on this tab: all, live, configs, packs, info, or a kind of asset such as textures
        #[arg(long)]
        tab: Option<String>,
        /// Open on the IDs tab and look these asset IDs up
        #[arg(long, num_args = 1.., conflicts_with = "tab")]
        fetch: Vec<String>,
    },
    /// Check GitHub for a newer release
    Update,
    /// Summarise the cache by category and content type
    Stats,
    /// List entries
    List {
        /// Only this content type (png, ktx2, mesh, ogg, rbxm, redirect, ...)
        #[arg(long)]
        kind: Option<String>,
        /// Only this category number (10 = assets, 11 = redirects)
        #[arg(long)]
        category: Option<i64>,
        /// Only entries whose id, type or URL contains this text
        #[arg(long)]
        search: Option<String>,
        /// Only entries at least this many bytes
        #[arg(long, default_value_t = 0)]
        min_size: u64,
        /// Include the cached redirect records
        #[arg(long)]
        redirects: bool,
        #[arg(long, value_enum, default_value_t = Sort::Size)]
        sort: Sort,
        /// Maximum rows to print (0 = all)
        #[arg(long, default_value_t = 50)]
        limit: usize,
    },
    /// Show everything known about one entry
    Info { id: String },
    /// Write the payload of an entry to a file
    Export {
        id: String,
        /// Output file [default: <id>.<ext> in the current folder]
        #[arg(short, long)]
        output: Option<PathBuf>,
        /// Keep the RBXH wrapper instead of extracting the payload
        #[arg(long)]
        raw: bool,
        /// Convert to a common format: KTX2 textures to PNG, meshes to OBJ
        #[arg(long, conflicts_with = "raw")]
        convert: bool,
    },
    /// Render a picture of a mesh, or one moment of an animation, to a PNG file
    Render {
        id: String,
        /// Output file [default: <id>.png in the current folder]
        #[arg(short, long)]
        output: Option<PathBuf>,
        /// Image width and height in pixels
        #[arg(long, default_value_t = 512)]
        size: usize,
        /// For animations: the moment to draw, in seconds
        #[arg(long, default_value_t = 0.0)]
        time: f32,
    },
    /// Export the payload of every entry of one content type into a folder
    ExportAll {
        out_dir: PathBuf,
        #[arg(long)]
        kind: String,
    },
    /// Replace the payload of an entry with a file, or with another cached entry
    Replace {
        id: String,
        /// File holding the new content
        #[arg(required_unless_present = "from")]
        file: Option<PathBuf>,
        /// Copy the content of this cache entry instead
        #[arg(long, conflicts_with = "file")]
        from: Option<String>,
    },
    /// Follow the cache as Roblox uses it, optionally keeping configs applied
    Watch {
        /// Re-apply this replacement config to every entry Roblox writes; may be given several times
        #[arg(long)]
        config: Vec<PathBuf>,
        /// Seconds between checks
        #[arg(long, default_value_t = 1.0)]
        interval: f32,
    },
    /// Record that a cache entry is the content of a Roblox asset ID
    Tag { id: String, asset_id: u64 },
    /// Apply one or more Fleasion-style replacement configs to the cache
    ApplyConfig {
        /// One or more config files; where two set the same entry, the later one has it
        #[arg(required = true)]
        files: Vec<PathBuf>,
        /// Only report what would change
        #[arg(long)]
        dry_run: bool,
        /// Do not look up the configs' asset IDs online first
        #[arg(long)]
        offline: bool,
    },
    /// Look up the asset IDs in one or more configs and match them to cached entries
    Identify {
        #[arg(required = true)]
        files: Vec<PathBuf>,
        /// Ask Roblox again about IDs that were already looked up
        #[arg(long)]
        refresh: bool,
    },
    /// Try to decode every texture, mesh and model, and report how many can be previewed
    Probe {
        /// Only this content type (ktx2, mesh, rbxm, rbxmx)
        #[arg(long)]
        kind: Option<String>,
        /// Stop after this many entries per type (0 = all)
        #[arg(long, default_value_t = 0)]
        limit: usize,
    },
    /// Empty the whole cache, so Roblox downloads everything again
    Clear {
        /// Close Roblox first if it is running
        #[arg(long)]
        close_roblox: bool,
    },
    /// Delete cached Rivals map skyboxes so Roblox downloads them again
    ClearSkyboxes {
        /// Only list the entries that would be deleted. The cache is opened for reading and nothing is changed
        #[arg(long)]
        dry_run: bool,
    },
    /// Delete entries (Roblox downloads them again when needed)
    Delete {
        #[arg(required = true)]
        ids: Vec<String>,
    },
    /// List the known packs, or download one and apply it
    Packs {
        /// Apply the pack with this id
        #[arg(long)]
        apply: Option<String>,
        /// With --apply: only report what would change
        #[arg(long, requires = "apply")]
        dry_run: bool,
    },
    /// Print the fingerprints recorded for the asset IDs in configs, to publish in packs.json
    Share {
        #[arg(required = true)]
        files: Vec<PathBuf>,
    },
    /// Look asset IDs up: what they are, the file when Roblox hands it out, and the cached sounds one might be
    Fetch {
        /// Asset IDs, links or rbxassetid:// addresses
        #[arg(required = true)]
        ids: Vec<String>,
        /// Save the files Roblox hands out into this folder
        #[arg(short, long)]
        output: Option<PathBuf>,
    },
    /// Add a Roblox account by its session cookie, so sounds and other assets Roblox
    /// keeps from guests can be fetched. This can be a main account; an alternate
    /// account is recommended, because whoever holds this cookie can sign in as that
    /// account. The cookie is not sent until the warning has been up for 5 seconds.
    /// Reads the cookie from stdin if not given, so it does not sit in your shell history
    Login {
        /// The account's .ROBLOSECURITY cookie, copied from your own already signed-in
        /// browser; AVOID passing it here if you can, since most shells keep a history
        cookie: Option<String>,
    },
    /// Removes an account from this computer. This does not end its Roblox session;
    /// to do that, sign out of that account on roblox.com
    Logout {
        /// The account's user ID or name; with none, the active account
        who: Option<String>,
    },
    /// List the added accounts
    Accounts,
    /// Show what changed in each version
    Changelog,
    /// Write the app icon as a PNG file
    #[command(hide = true)]
    Icon {
        output: PathBuf,
        #[arg(long, default_value_t = 1024)]
        size: u32,
    },
}

#[derive(Clone, Copy, ValueEnum)]
pub enum Sort {
    Size,
    Hits,
    Recent,
    Id,
}

pub fn run(dir: &Path, idmap_path: &Path, cmd: Cmd) -> Result<()> {
    // Sign requests with the signed-in account, and name a game when Roblox refuses, so
    // sounds and other assets a guest cannot reach are matched from the terminal too.
    crate::account::activate();
    crate::resolve::set_place(crate::store::latest_place_id(dir));
    match cmd {
        Cmd::Gui { .. } => unreachable!("handled by main"),
        Cmd::Update => {
            let release = crate::update::latest()?;
            if release.is_newer() {
                println!("rbxcache {} is available (this is {}): {}", release.version, crate::update::CURRENT, release.url);
                print_versions(&release.news);
            } else {
                println!("rbxcache {} is the latest release", crate::update::CURRENT);
            }
            Ok(())
        }
        Cmd::Stats => stats(&Store::open(dir, false)?),
        Cmd::List { kind, category, search, min_size, redirects, sort, limit } => {
            let store = Store::open(dir, false)?;
            let mut entries = store.list(|_, _| {})?;
            let search = search.map(|s| s.to_lowercase());
            let want_redirects = redirects || kind.as_deref() == Some("redirect") || category == Some(11);
            entries.retain(|e| {
                (want_redirects || e.kind != "redirect")
                    && kind.as_deref().is_none_or(|k| e.kind == k)
                    && category.is_none_or(|c| e.category == c)
                    && e.size >= min_size
                    && search.as_deref().is_none_or(|s| matches(e, s))
            });
            match sort {
                Sort::Size => entries.sort_by_key(|e| Reverse(e.size)),
                Sort::Hits => entries.sort_by_key(|e| Reverse(e.hits)),
                Sort::Recent => entries.sort_by_key(|e| Reverse(e.atime)),
                Sort::Id => entries.sort_by_key(|e| e.id),
            }
            let shown = if limit == 0 { entries.len() } else { limit.min(entries.len()) };
            println!("{:<32}  {:<12} {:>10} {:>7}  LAST USED", "ID", "TYPE", "SIZE", "HITS");
            for e in &entries[..shown] {
                println!("{:<32}  {:<12} {:>10} {:>7}  {}", e.id_hex, e.kind, human_size(e.size), e.hits, format_time_ms(e.atime));
            }
            println!("{shown} of {} matching entries shown", entries.len());
            Ok(())
        }
        Cmd::Info { id } => {
            let store = Store::open(dir, false)?;
            let id = store.resolve(&id)?;
            let e = store.entry(&id)?;
            let (raw, header) = store.read_parsed(&id)?;
            for (k, v) in describe(&store, &e, &raw, header.as_ref()) {
                println!("{k:<16} {v}");
            }
            Ok(())
        }
        Cmd::Export { id, output, raw, convert } => {
            let store = Store::open(dir, false)?;
            let id = store.resolve(&id)?;
            let e = store.entry(&id)?;
            let mut data = if raw { store.read(&id)? } else { store.read_body(&id)? };
            let mut name = export_name(&e, raw);
            if convert {
                let (converted, extension) = crate::viewers::convert(e.kind, &data)?;
                (data, name) = (converted, format!("{}.{extension}", e.id_hex));
            }
            let out = output.unwrap_or_else(|| name.into());
            std::fs::write(&out, &data).with_context(|| format!("writing {}", out.display()))?;
            println!("wrote {} ({})", out.display(), human_size(data.len() as u64));
            Ok(())
        }
        Cmd::Render { id, output, size, time } => {
            let store = Store::open(dir, false)?;
            let id = store.resolve(&id)?;
            let e = store.entry(&id)?;
            let body = store.read_body(&id)?;
            let size = size.clamp(16, 4096);
            let (picture, what) = if matches!(e.kind, "rbxm" | "rbxmx") {
                let model = crate::viewers::parse_model(&body, e.kind == "rbxmx")?;
                let animation = model.animation.context("this model holds no R6 or R15 keyframe animation")?;
                let figure = animation.pose(time.clamp(0.0, animation.length));
                let picture = figure.render(&View::new(animation.bounds(), crate::viewers::FIGURE_ANGLES), size, size, crate::viewers::MESH_TINT);
                (picture, format!("{} animation, {} keyframes, {:.2}s", animation.rig.name(), animation.keyframes, animation.length))
            } else {
                let mesh = crate::viewers::parse_mesh(&body)?;
                let picture = mesh.render(&View::new(mesh.bounds(), crate::viewers::MESH_ANGLES), size, size, crate::viewers::MESH_TINT);
                (picture, format!("{} vertices, {} triangles, version {}", mesh.positions.len(), mesh.faces.len(), mesh.version))
            };
            let out = output.unwrap_or_else(|| format!("{}.png", store::hex(&id)).into());
            image::RgbaImage::from_raw(size as u32, size as u32, picture.pixels)
                .context("rendered picture has the wrong size")?
                .save(&out)
                .with_context(|| format!("writing {}", out.display()))?;
            println!("wrote {} ({what})", out.display());
            Ok(())
        }
        Cmd::ExportAll { out_dir, kind } => {
            let store = Store::open(dir, false)?;
            let entries = store.list(|_, _| {})?;
            std::fs::create_dir_all(&out_dir)?;
            let (mut n, mut bytes, mut failed) = (0usize, 0u64, 0usize);
            for e in entries.iter().filter(|e| e.kind == kind) {
                let path = out_dir.join(export_name(e, false));
                match store.read_body(&e.id).and_then(|data| Ok((std::fs::write(&path, &data)?, data.len()))) {
                    Ok(((), len)) => {
                        n += 1;
                        bytes += len as u64;
                    }
                    Err(err) => {
                        eprintln!("{}: {err:#}", e.id_hex);
                        failed += 1;
                    }
                }
            }
            println!("exported {n} {kind} entries ({}) to {}", human_size(bytes), out_dir.display());
            if failed > 0 {
                bail!("{failed} entries could not be exported");
            }
            Ok(())
        }
        Cmd::Replace { id, file, from } => {
            let store = Store::open(dir, true)?;
            warn_if_running();
            let id = store.resolve(&id)?;
            let body = match (file, from) {
                (Some(file), _) => std::fs::read(&file).with_context(|| format!("reading {}", file.display()))?,
                (None, Some(from)) => store.read_body(&store.resolve(&from)?)?,
                (None, None) => unreachable!("clap requires a file or --from"),
            };
            let entries = store.list(|_, _| {})?;
            for (e, _) in config::replace_by_hand(&store, &entries, &id, body)? {
                println!("replaced {} - now {} ({})", e.id_hex, e.kind, human_size(e.size));
            }
            Ok(())
        }
        Cmd::Watch { config, interval } => watch(dir, idmap_path, &config, interval),
        Cmd::Tag { id, asset_id } => {
            let store = Store::open(dir, false)?;
            let id = store.resolve(&id)?;
            let mut idmap = IdMap::load(idmap_path)?;
            let fp = config::fingerprint(&store.read_body(&id)?);
            if idmap.add(asset_id, fp) {
                idmap.save(idmap_path)?;
                println!("asset {asset_id} -> {} recorded in {}", store::hex(&id), idmap_path.display());
            } else {
                println!("asset {asset_id} already has this content recorded");
            }
            Ok(())
        }
        Cmd::Identify { files, refresh } => {
            let rules = config::load_all(&files)?;
            let store = Store::open(dir, false)?;
            let entries = store.list(|_, _| {})?;
            let mut idmap = IdMap::load(idmap_path)?;
            for (id, outcome) in identify(&store, &entries, &mut idmap, idmap_path, &rules, refresh)? {
                println!("{id:<18} {outcome}");
            }
            Ok(())
        }
        Cmd::ApplyConfig { files, dry_run, offline } => apply_configs(dir, idmap_path, &files, dry_run, offline),
        Cmd::Packs { apply: None, .. } => {
            // The list on GitHub, or the one built in when that cannot be reached.
            let catalog = crate::packs::fetch().unwrap_or_else(|e| {
                eprintln!("{e:#}; showing the list this version was built with");
                crate::packs::bundled()
            });
            for pack in &catalog.packs {
                let by = if pack.author.is_empty() { String::new() } else { format!(" by {}", pack.author) };
                println!("{:<16} {}{by}  [{}]\n{:<16} {}", pack.id, pack.name, pack.game, "", pack.description);
            }
            println!("{}; apply one with: rbxcache packs --apply <id>", format::count(catalog.packs.len(), "pack", "packs"));
            Ok(())
        }
        Cmd::Packs { apply: Some(id), dry_run } => {
            let catalog = crate::packs::fetch()?;
            let pack =
                catalog.packs.iter().find(|p| p.id == id).with_context(|| format!("there is no pack '{id}'; run 'rbxcache packs' for the list"))?;
            // A dry run leaves nothing behind: the config goes to the temp folder and the ID map stays as it is.
            let path = if dry_run { pack.install_into(&std::env::temp_dir().join("rbxcache-packs"))? } else { pack.install()? };
            println!("{} saved to {}", pack.name, path.display());
            let mut idmap = IdMap::load(idmap_path)?;
            if !dry_run && idmap.merge(&catalog.fingerprints) > 0 {
                idmap.save(idmap_path)?;
            }
            apply_configs(dir, idmap_path, &[path], dry_run, dry_run)
        }
        Cmd::Share { files } => {
            let rules = config::load_all(&files)?;
            let idmap = IdMap::load(idmap_path)?;
            let ids = config::asset_ids(&rules);
            let mut known = IdMap::default();
            for id in &ids {
                for fp in idmap.assets.get(&id.to_string()).into_iter().flatten() {
                    known.add(*id, fp.clone());
                }
            }
            println!("{}", serde_json::to_string_pretty(&known)?);
            eprintln!(
                "{} of {} have a fingerprint; paste these under \"fingerprints\" in packs.json",
                known.assets.len(),
                format::count(ids.len(), "asset ID", "asset IDs")
            );
            Ok(())
        }
        Cmd::Fetch { ids, output } => {
            use crate::resolve::Outcome;
            if crate::account::Accounts::load().is_empty() {
                bail!("fetching IDs needs a signed-in account: run `rbxcache login` first (an alternate account is fine)");
            }
            let Some(who) = crate::account::check_active()? else { bail!("no signed-in account is in use") };
            println!("Fetching as @{}", who.name);
            let ids = crate::lookup::parse_ids(&ids.join(" "));
            if ids.is_empty() {
                bail!("no asset ID was given: a number such as 16530229616");
            }
            let store = Store::open(dir, false)?;
            let entries = store.list(|_, _| {})?;
            let mut idmap = IdMap::load(idmap_path)?;
            let found = crate::lookup::find(&store, &entries, &mut idmap, &ids, &|_, _| {});
            idmap.save(idmap_path)?;
            let sounds = if found.iter().any(|f| matches!(f.outcome, Outcome::Denied(_))) {
                crate::lookup::sounds(&store, &entries, &idmap)
            } else {
                Vec::new()
            };
            for item in &found {
                let details = item.details.clone().unwrap_or_default();
                let kind = details.type_id.map_or("unknown type", format::asset_type_name);
                println!(
                    "{}  {}  ({kind}){}",
                    item.id,
                    if details.name.is_empty() { "no public details" } else { &details.name },
                    details.seconds.map_or(String::new(), |s| format!(", about {s} s"))
                );
                println!("    {}", item.outcome);
                if let Some((kind, body)) = &item.file {
                    match &output {
                        Some(folder) => {
                            std::fs::create_dir_all(folder)?;
                            let path = folder.join(format!("{}.{}", item.id, format::extension(kind)));
                            std::fs::write(&path, &body[..]).with_context(|| format!("writing {}", path.display()))?;
                            println!("    saved {} ({})", path.display(), human_size(body.len() as u64));
                        }
                        None => println!("    {kind}, {}; pass -o <folder> to save it", human_size(body.len() as u64)),
                    }
                }
                // Refused and a sound, or refused with nothing known: the cached sounds it could be.
                if matches!(item.outcome, Outcome::Denied(_)) && (item.details.is_none() || item.is_sound()) {
                    let candidates = crate::lookup::candidates(&sounds, details.seconds);
                    println!(
                        "    {} could be it; listen in the window's IDs tab, or tie one with: rbxcache tag <entry> {}",
                        format::count(candidates.len(), "cached sound", "cached sounds"),
                        item.id
                    );
                    for sound in candidates.iter().take(12) {
                        println!(
                            "      {}  {:>8}  {}",
                            store::hex(&sound.id),
                            sound.seconds.map_or("?".to_string(), |s| format!("{s:.2} s")),
                            human_size(sound.size)
                        );
                    }
                }
            }
            Ok(())
        }
        Cmd::Login { cookie } => {
            println!("{}\n", crate::account::WARNING);
            let pasted = match cookie {
                Some(cookie) => cookie,
                None => {
                    println!("Paste the .ROBLOSECURITY cookie from your own already signed-in browser, then press Enter:");
                    let mut line = String::new();
                    std::io::stdin().read_line(&mut line).context("could not read the cookie")?;
                    line
                }
            };
            let cookie = crate::account::extract(&pasted).context("that did not look like a cookie")?;
            let seconds = crate::account::SUBMIT_HOLD.as_secs();
            println!("Sending it in {seconds} seconds. Press Ctrl+C to stop.");
            for left in (1..=seconds).rev() {
                println!("{left}...");
                std::thread::sleep(std::time::Duration::from_secs(1));
            }
            let who = crate::account::whoami(&cookie)?;
            let mut accounts = crate::account::Accounts::load();
            accounts.add(who.clone(), &cookie)?;
            println!("added {} (@{}, {})", who.display, who.name, who.user_id);
            Ok(())
        }
        Cmd::Logout { who } => {
            let mut accounts = crate::account::Accounts::load();
            let id = match &who {
                Some(text) => accounts
                    .accounts
                    .iter()
                    .find(|a| a.user_id.to_string() == *text || a.name.eq_ignore_ascii_case(text))
                    .map(|a| a.user_id)
                    .with_context(|| format!("no added account matches '{text}'"))?,
                None => accounts.active().map(|a| a.user_id).context("no account has been added")?,
            };
            accounts.remove(id)?;
            println!("removed {id} from this computer; its Roblox session is not ended, sign out of it on roblox.com if you want that too");
            Ok(())
        }
        Cmd::Accounts => {
            let accounts = crate::account::Accounts::load();
            if accounts.is_empty() {
                println!("no account has been added; run: rbxcache login");
            }
            for account in &accounts.accounts {
                let mark = if accounts.active().is_some_and(|a| a.user_id == account.user_id) { "*" } else { " " };
                println!("{mark} {:<12} {} (@{})", account.user_id, account.display, account.name);
            }
            Ok(())
        }
        Cmd::Changelog => {
            print_versions(&crate::changelog::bundled());
            Ok(())
        }
        Cmd::Icon { output, size } => {
            let size = size.clamp(16, 2048);
            image::RgbaImage::from_raw(size, size, crate::theme::app_icon(size))
                .context("the icon has the wrong size")?
                .save(&output)
                .with_context(|| format!("writing {}", output.display()))
        }
        Cmd::Probe { kind, limit } => {
            let store = Store::open(dir, false)?;
            let entries = store.list(|_, _| {})?;
            if kind.is_none() {
                let (mut good, mut bad) = (0usize, 0usize);
                for e in entries.iter().filter(|e| e.wrapped && e.kind != "missing").take(if limit == 0 { usize::MAX } else { limit }) {
                    let Ok((raw, Some(h))) = store.read_parsed(&e.id) else { continue };
                    let headers = &raw[h.body_offset - h.headers.len().min(h.body_offset)..h.body_offset];
                    if format::checksum(&raw[h.body_offset..]) == h.body_sum && format::checksum(headers) == h.header_sum {
                        good += 1;
                    } else {
                        bad += 1;
                    }
                }
                println!("checksums {good:>6} match, {bad:>5} differ");
            }
            for want in ["ktx2", "mesh", "rbxm", "rbxmx"] {
                if kind.as_deref().is_some_and(|k| k != want) {
                    continue;
                }
                let (mut ok, mut failed) = (0usize, 0usize);
                let mut animations: BTreeMap<&str, usize> = BTreeMap::new();
                let mut errors: BTreeMap<String, (usize, String)> = BTreeMap::new();
                let started = std::time::Instant::now();
                for e in entries.iter().filter(|e| e.kind == want).take(if limit == 0 { usize::MAX } else { limit }) {
                    let result = store.read_body(&e.id).and_then(|body| match want {
                        "ktx2" => crate::viewers::decode_ktx2(&body, 1024).map(|_| ()),
                        "mesh" => crate::viewers::parse_mesh(&body).map(|_| ()),
                        _ => crate::viewers::parse_model(&body, want == "rbxmx").map(|model| {
                            if let Some(animation) = model.animation {
                                *animations.entry(animation.rig.name()).or_insert(0usize) += 1;
                            }
                        }),
                    });
                    match result {
                        Ok(()) => ok += 1,
                        Err(err) => {
                            failed += 1;
                            let slot = errors.entry(format!("{err:#}").chars().take(70).collect()).or_insert((0, e.id_hex.clone()));
                            slot.0 += 1;
                        }
                    }
                }
                println!("{want:<6} {ok:>6} decoded, {failed:>5} failed  ({:.1}s)", started.elapsed().as_secs_f32());
                for (rig, n) in animations {
                    println!("    {n:>5} playable {rig} animations");
                }
                for (message, (n, example)) in errors {
                    println!("    {n:>5} x {message}  e.g. {example}");
                }
            }
            Ok(())
        }
        Cmd::Clear { close_roblox } => {
            for step in store::clear_cache(dir, close_roblox)? {
                println!("{step}");
            }
            Ok(())
        }
        Cmd::ClearSkyboxes { dry_run } => {
            let mut idmap = IdMap::load(idmap_path)?;
            idmap.merge(&crate::packs::bundled().fingerprints);
            let store = Store::open(dir, !dry_run)?;
            let entries = store.list(|_, _| {})?;
            // With the saved originals, a skybox a config has replaced is still known as that skybox.
            let originals = crate::originals::Originals::load_default().ok();
            if dry_run {
                let ids = config::entries_of(&store, &entries, &idmap, config::RIVALS_SKYBOX_IDS, originals.as_ref())?;
                for entry in entries.iter().filter(|entry| ids.contains(&entry.id)) {
                    let replaced = originals.as_ref().is_some_and(|originals| originals.probably_replaced(entry).is_some());
                    let note = if replaced { "  holds a config's replacement" } else { "" };
                    println!("{}  {:<6} {:>10}{note}", entry.id_hex, entry.kind, human_size(entry.body_len));
                }
                let known = |id: &&u64| idmap.assets.get(&id.to_string()).is_some_and(|prints| !prints.is_empty());
                println!(
                    "{} would be deleted. {} of {} skybox IDs have been looked up; the rest cannot be recognised yet.",
                    format::count(ids.len(), "skybox entry", "skybox entries"),
                    config::RIVALS_SKYBOX_IDS.iter().filter(known).count(),
                    config::RIVALS_SKYBOX_IDS.len()
                );
                return Ok(());
            }
            warn_if_running();
            let (deleted, failed, _) = config::delete_assets(&store, &entries, &idmap, config::RIVALS_SKYBOX_IDS, originals.as_ref())?;
            if deleted == 0 && failed == 0 {
                println!("No Rivals skyboxes were in the cache");
            } else {
                println!("Deleted {}", format::count(deleted, "skybox entry", "skybox entries"));
            }
            if failed > 0 {
                bail!("{failed} skybox entries could not be deleted");
            }
            Ok(())
        }
        Cmd::Delete { ids } => {
            let store = Store::open(dir, true)?;
            warn_if_running();
            let mut failed = 0;
            for id in &ids {
                match store.resolve(id).and_then(|id| store.delete(&id).map(|()| id)) {
                    Ok(id) => println!("deleted {}", store::hex(&id)),
                    Err(e) => {
                        eprintln!("{id}: {e}");
                        failed += 1;
                    }
                }
            }
            if failed > 0 {
                bail!("{failed} of {} entries could not be deleted", ids.len());
            }
            Ok(())
        }
    }
}

fn print_versions(versions: &[crate::changelog::Version]) {
    for version in versions {
        let date = if version.date.is_empty() { String::new() } else { format!("  ({})", version.date) };
        println!("\n{}{date}", version.version);
        for change in &version.changes {
            println!("  - {change}");
        }
    }
}

/// Looks up the asset IDs the configs name, unless `offline`, and applies the configs.
fn apply_configs(dir: &Path, idmap_path: &Path, files: &[PathBuf], dry_run: bool, offline: bool) -> Result<()> {
    let rules = config::load_all(files)?;
    let store = Store::open(dir, !dry_run)?;
    if !dry_run {
        warn_if_running();
    }
    let entries = store.list(|_, _| {})?;
    let mut idmap = IdMap::load(idmap_path)?;
    if !offline {
        identify(&store, &entries, &mut idmap, idmap_path, &rules, false)?;
    }
    let reports = config::run(&store, &entries, &idmap, &rules, !dry_run, None, None);
    for r in &reports {
        let mut absent = Vec::new();
        if r.waiting > 0 {
            absent.push(format!("{} not cached", r.waiting));
        }
        if r.refused > 0 {
            absent.push(format!("{} not handed out", r.refused));
        }
        let absent = if absent.is_empty() { String::new() } else { format!("  ({})", absent.join(", ")) };
        println!("{:<28} matched {:>5}  {} {:>5}{absent}", r.name, r.matched, if dry_run { "would change" } else { "changed" }, r.changed);
        for note in &r.notes {
            println!("    ! {note}");
        }
    }
    println!("{}", config::summarize(&reports, !dry_run));
    Ok(())
}

/// Prints cache activity until interrupted, re-applying `configs` to what Roblox writes.
fn watch(dir: &Path, idmap_path: &Path, configs: &[PathBuf], interval: f32) -> Result<()> {
    use crate::watch::{merge, Tracker, Verdict, Watcher};
    let rules = if configs.is_empty() { None } else { Some(config::load_all(configs)?) };
    let mut idmap = IdMap::load(idmap_path)?;
    let store = Store::open(dir, rules.is_some())?;
    let mut entries = store.list(|_, _| {})?;
    if let Some(rules) = &rules {
        identify(&store, &entries, &mut idmap, idmap_path, rules, false)?;
    }
    let mut tracker = Tracker::default();
    if let Some(rules) = &rules {
        for report in config::run(&store, &entries, &idmap, rules, true, None, None) {
            for entry in &report.written {
                println!("= applied   {:<12} {}  ({})", entry.kind, entry.id_hex, report.name);
                tracker.record(entry);
            }
        }
        entries = store.list(|_, _| {})?;
    }
    let mut watcher = Watcher::new(dir, entries.iter().map(Entry::stamp))?;
    println!("watching {} ({}); Ctrl+C to stop", dir.display(), format::count(entries.len(), "entry", "entries"));
    loop {
        std::thread::sleep(std::time::Duration::from_secs_f32(interval.clamp(0.2, 60.0)));
        let Some(change) = watcher.poll()? else { continue };
        let known: std::collections::HashSet<store::Id> = entries.iter().map(|e| e.id).collect();
        for verdict in tracker.observe(&change) {
            match verdict {
                Verdict::Read { id, reads } => println!("  read      {} replacement read {reads} time(s) and kept", store::hex(&id)),
                Verdict::Reverted { id, times } => println!("! reverted  {} Roblox wrote this entry again ({times}x)", store::hex(&id)),
            }
        }
        // Our own replacements come back as writes too; those were already reported.
        for e in change.written.iter().filter(|e| !tracker.holds(e)) {
            let mark = if known.contains(&e.id) { "~ rewritten" } else { "+ new      " };
            println!("{mark} {:<12} {:>10}  {}", e.kind, human_size(e.size), e.id_hex);
        }
        for id in &change.removed {
            println!("- removed   {}", store::hex(id));
        }
        merge(&mut entries, &change);
        let Some(rules) = &rules else { continue };
        let fresh: std::collections::HashSet<store::Id> = change.written.iter().map(|e| e.id).filter(|id| tracker.may_replace(id)).collect();
        if fresh.is_empty() {
            continue;
        }
        for report in config::run(&store, &entries, &idmap, rules, true, Some(&fresh), None) {
            for entry in &report.written {
                println!("= applied   {:<12} {}  ({})", entry.kind, entry.id_hex, report.name);
                tracker.record(entry);
            }
            for note in report.notes.iter().filter(|_| report.matched > 0) {
                println!("  ! {}: {note}", report.name);
            }
        }
    }
}

/// Looks up the asset IDs `rules` mention, saves what was learned to the ID map
/// and prints a one-line summary. Returns what happened to each ID.
fn identify(
    store: &Store,
    entries: &[Entry],
    idmap: &mut IdMap,
    idmap_path: &Path,
    rules: &[config::Rule],
    refresh: bool,
) -> Result<Vec<(u64, crate::resolve::Outcome)>> {
    let ids = config::asset_ids(rules);
    if ids.is_empty() {
        return Ok(Vec::new());
    }
    eprintln!("looking up {}...", format::count(ids.len(), "asset ID", "asset IDs"));
    let outcomes = crate::resolve::identify(store, entries, idmap, &ids, refresh, &|_, _| {});
    idmap.save(idmap_path)?;
    println!("{}", crate::resolve::summarize(&outcomes));
    Ok(outcomes)
}

fn warn_if_running() {
    if store::roblox_running() {
        eprintln!("warning: Roblox is running and may overwrite or ignore changes to its cache");
    }
}

pub fn matches(e: &Entry, needle_lower: &str) -> bool {
    e.id_hex.contains(needle_lower) || e.kind.contains(needle_lower) || e.url.to_lowercase().contains(needle_lower)
}

pub fn export_name(e: &Entry, raw: bool) -> String {
    format!("{}.{}", e.id_hex, if raw { "rbxh" } else { format::extension(e.kind) })
}

/// Key/value description of an entry, shared by `info` and the window's detail panel.
pub fn describe(store: &Store, e: &Entry, raw: &[u8], header: Option<&format::Header>) -> Vec<(&'static str, String)> {
    let body = &raw[header.map_or(0, |h| h.body_offset)..];
    let mut out = vec![
        ("ID", e.id_hex.clone()),
        ("Type", e.kind.to_string()),
        ("Category", format!("{} ({})", e.category, category_name(e.category))),
        ("Stored size", format!("{} ({} bytes)", human_size(raw.len() as u64), raw.len())),
        ("Payload size", format!("{} ({} bytes)", human_size(body.len() as u64), body.len())),
        ("Hits", e.hits.to_string()),
        ("Last used", format_time_ms(e.atime)),
    ];
    if e.ttl > 0 {
        out.push(("Expires", format_time_ms(e.ttl * 1000)));
    }
    out.push(("Stored in", if e.inline { "database (inline)".into() } else { store.blob_path(&e.id).display().to_string() }));
    if let Some(d) = payload_details(e.kind, body) {
        out.push(("Details", d));
    }
    match header {
        Some(h) => {
            out.push(("HTTP status", h.status.to_string()));
            if let Some(t) = e.asset_type {
                out.push(("Asset type", format!("{t} ({})", format::asset_type_name(t))));
            }
            if !h.url.is_empty() {
                out.push(("URL", h.url.clone()));
            }
            if !h.headers.trim().is_empty() {
                out.push(("Headers", h.headers.trim().replace("\r\n", "; ")));
            }
            out.push(("Checksums", format!("headers {:08x}, body {:08x} (stored length {})", h.header_sum, h.body_sum, h.body_len)));
        }
        None => out.push(("Wrapper", "none (raw blob)".into())),
    }
    out
}

/// Format-specific facts read from the payload itself.
fn payload_details(kind: &str, body: &[u8]) -> Option<String> {
    let u32at = |o: usize| body.get(o..o + 4).map(|b| u32::from_le_bytes(b.try_into().unwrap()));
    match kind {
        "png" | "jpeg" | "gif" | "webp" => {
            let reader = image::ImageReader::new(std::io::Cursor::new(body)).with_guessed_format().ok()?;
            let (w, h) = reader.into_dimensions().ok()?;
            Some(format!("{w} x {h} px"))
        }
        "ktx2" => {
            let compression = match u32at(44)? {
                0 => "none",
                1 => "BasisLZ",
                2 => "Zstandard",
                3 => "ZLIB",
                _ => "unknown",
            };
            Some(format!(
                "{} x {} px, {} mip level(s), vkFormat {}, supercompression {compression}",
                u32at(20)?,
                u32at(24)?,
                u32at(40)?.max(1),
                u32at(12)?
            ))
        }
        "mesh" => {
            let line = body.split(|&c| c == b'\n').next()?;
            Some(String::from_utf8_lossy(line).trim().to_string())
        }
        _ => None,
    }
}

fn stats(store: &Store) -> Result<()> {
    let mut last = 0;
    let entries = store.list(|done, total| {
        if total > 0 && done * 10 / total != last {
            last = done * 10 / total;
            eprint!("\rscanning {}%", last * 10);
        }
    })?;
    eprintln!();
    let mut by_cat: BTreeMap<i64, (usize, u64)> = BTreeMap::new();
    let mut by_kind: BTreeMap<&str, (usize, u64)> = BTreeMap::new();
    for e in &entries {
        for slot in [by_cat.entry(e.category).or_default(), by_kind.entry(e.kind).or_default()] {
            slot.0 += 1;
            slot.1 += e.size;
        }
    }
    let total: u64 = entries.iter().map(|e| e.size).sum();
    println!("{} entries, {} in {}", entries.len(), human_size(total), store.dir.display());
    println!("\n{:<22} {:>8} {:>12}", "CATEGORY", "ENTRIES", "SIZE");
    for (c, (n, s)) in &by_cat {
        println!("{:<22} {n:>8} {:>12}", format!("{c} ({})", category_name(*c)), human_size(*s));
    }
    let mut kinds: Vec<_> = by_kind.into_iter().collect();
    kinds.sort_by_key(|(_, (_, size))| Reverse(*size));
    println!("\n{:<22} {:>8} {:>12}", "TYPE", "ENTRIES", "SIZE");
    for (k, (n, s)) in kinds {
        println!("{k:<22} {n:>8} {:>12}", human_size(s));
    }
    Ok(())
}
