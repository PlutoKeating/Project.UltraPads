# JSON Schema / XSD

| 文件 | 校验对象 | 代码 |
|---|---|---|
| `ultrapads-kit-1.schema.json` | `.upkit` 中的 `ultrapads-kit.json` | `up_format::kit_json` |
| `manifest-1.schema.json` | `.upkit` 中的 `manifest.json` | `up_format::manifest` |
| `tutorial-1.schema.json` | `tutorials/<id>/tutorial.json` | `up_format::tutorial` |
| `library-1.schema.json` | 曲库数据根目录下的 `library.json` | `up_library::index` |
| `dawproject/Project.xsd`、`dawproject/MetaData.xsd` | DAWproject 1.0 的 `project.xml` / `metadata.xml` | `up_format::dawproject` |

`dawproject/` 下的 XSD 原样取自 https://github.com/bitwig/dawproject（commit `ee4dcdde75940f30e14e55401a26955a58b8322b`，MIT，见 `dawproject/LICENSE`）。
`up-format` / `up-library` 的测试用这些 Schema 校验序列化结果（XSD 校验需要 `xmllint`）。
