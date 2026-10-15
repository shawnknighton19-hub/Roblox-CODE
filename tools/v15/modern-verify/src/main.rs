//! Read-only independent decoder for modern Roblox binary places/models.
//! No serialization/projection/property stripping is performed.
use std::collections::BTreeMap;
use std::fs;
use std::io::Cursor;
use std::sync::Mutex;

use rbx_dom_weak::types::{PhysicalProperties, Ref, Variant};
use rbx_dom_weak::WeakDom;
use serde::Serialize;
use sha2::{Digest, Sha256};

struct Capture;
static LOGGER: Capture = Capture;
static WARNINGS: Mutex<Vec<String>> = Mutex::new(Vec::new());
impl log::Log for Capture {
    fn enabled(&self, metadata: &log::Metadata) -> bool { metadata.level() <= log::Level::Warn }
    fn log(&self, record: &log::Record) {
        if self.enabled(record.metadata()) {
            WARNINGS.lock().unwrap().push(format!("{}: {}", record.level(), record.args()));
        }
    }
    fn flush(&self) {}
}

#[derive(Serialize)]
struct ScriptInfo {
    path: String,
    class: String,
    source_sha256: String,
    bytes: usize,
}

#[derive(Default, Serialize)]
struct PhysicalInfo {
    property_count: usize,
    defaults: usize,
    custom: usize,
    acoustic_absorption_not_one: usize,
    property_counts_by_class: BTreeMap<String, usize>,
}

#[derive(Serialize)]
struct Report {
    decoder: &'static str,
    read_only: bool,
    file_sha256: String,
    file_bytes: usize,
    instance_count: usize,
    script_count: usize,
    warnings: String,
    warning_count: usize,
    scripts: Vec<ScriptInfo>,
    physical_properties: PhysicalInfo,
    supported_physical_discriminators: [u8; 4],
    native_studio_tested: bool,
}

fn sha(bytes: &[u8]) -> String { format!("{:x}", Sha256::digest(bytes)) }

fn visit(dom: &WeakDom, reference: Ref, parent: &str, report: &mut Report) -> Result<(), String> {
    let instance = dom.get_by_ref(reference).ok_or("Broken instance referent")?;
    let path = if parent.is_empty() { instance.name.clone() } else { format!("{parent}/{}", instance.name) };
    report.instance_count += 1;
    for (name, value) in &instance.properties {
        if name.as_str() == "Source" {
            let bytes: &[u8] = match value {
                Variant::String(source) => source.as_bytes(),
                Variant::BinaryString(source) => source.as_ref(),
                other => return Err(format!("Unexpected Source type at {path}: {other:?}")),
            };
            report.scripts.push(ScriptInfo {
                path: path.clone(), class: instance.class.to_string(),
                source_sha256: sha(bytes), bytes: bytes.len(),
            });
        }
        if let Variant::PhysicalProperties(properties) = value {
            report.physical_properties.property_count += 1;
            *report.physical_properties.property_counts_by_class.entry(instance.class.to_string()).or_default() += 1;
            match properties {
                PhysicalProperties::Default => report.physical_properties.defaults += 1,
                PhysicalProperties::Custom(custom) => {
                    report.physical_properties.custom += 1;
                    if custom.acoustic_absorption() != 1.0 {
                        report.physical_properties.acoustic_absorption_not_one += 1;
                    }
                }
            }
        }
    }
    for &child in instance.children() { visit(dom, child, &path, report)?; }
    Ok(())
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    log::set_logger(&LOGGER).map_err(|_| "Could not install warning logger")?;
    log::set_max_level(log::LevelFilter::Warn);
    let path = std::env::args().nth(1).ok_or("Usage: hab-rbxl-verify INPUT.rbxl")?;
    let input = fs::read(&path)?;
    let dom = rbx_binary::from_reader(Cursor::new(&input))?;
    let mut report = Report {
        decoder: "rbx_binary 3.0.1 / rbx_dom_weak 4.2.0", read_only: true,
        file_sha256: sha(&input), file_bytes: input.len(), instance_count: 0,
        script_count: 0, warnings: String::new(), warning_count: 0,
        scripts: Vec::new(), physical_properties: PhysicalInfo::default(),
        supported_physical_discriminators: [0,1,2,3], native_studio_tested: false,
    };
    // rbx_binary adds an artificial DataModel root. Count only serialized instances.
    for &root in dom.root().children() { visit(&dom, root, "", &mut report)?; }
    report.script_count = report.scripts.len();
    report.scripts.sort_by(|a,b| a.path.cmp(&b.path).then(a.source_sha256.cmp(&b.source_sha256)));
    let warnings = WARNINGS.lock().unwrap();
    report.warning_count = warnings.len();
    report.warnings = warnings.join("\n");
    println!("{}", serde_json::to_string(&report)?);
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("Modern RBXL verification failed: {error}");
        std::process::exit(1);
    }
}
