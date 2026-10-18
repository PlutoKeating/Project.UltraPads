//! 生成原创示例 Kit：`cargo run -p up-library --example kitgen -- content/kits`
//!
//! 所有声音由 `up_library::kitgen` 用代码合成，素材 100% 原创（CC0-1.0），可以公开入库。

use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let out = std::env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("content/kits"));
    std::fs::create_dir_all(&out)?;
    for (file, pkg) in up_library::kitgen::example_packages()? {
        let bytes = up_library::archive::zip_to_vec(&pkg.zip_entries())?;
        let path = out.join(&file);
        std::fs::write(&path, &bytes)?;
        println!(
            "{}  {} 字节  {} 个文件",
            path.display(),
            bytes.len(),
            pkg.files.len()
        );
    }
    Ok(())
}
