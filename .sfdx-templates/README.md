# SFDX Metadata Templates

Canonical, verified-good templates for every metadata type the dev agent
commonly emits. **Copy these verbatim** and modify ONLY the marked fields.

Why templates: LLMs follow concrete examples ~3–5× more reliably than
abstract prose rules. The recurring deploy failures we see
(missing `<label>` on `__c`, `<apiVersion>` on `PermissionSet`,
`screen` instead of `screens` in Flow, `editHeading>Lead Information<`
instead of `<editHeading>true<`) are all things LLMs get *right* when
they paraphrase from a template and *wrong* when they synthesize from
text instructions.

## Files

| File | Use when emitting |
|---|---|
| `sfdx/CustomObject.object-meta.xml` | Any `__c` Custom Object parent file |
| `sfdx/CustomMetadataType.object-meta.xml` | Any `__mdt` Custom Metadata Type parent file |
| `sfdx/CustomField.field-meta.xml` | Any `force-app/main/default/objects/<Obj>__c/fields/<Field>__c.field-meta.xml` |
| `sfdx/PermissionSet.permissionset-meta.xml` | Any `.permissionset-meta.xml` |
| `sfdx/ApexClass.cls` + `sfdx/ApexClass.cls-meta.xml` | Any production Apex class |
| `sfdx/ApexTestClass.cls` | Required test class — emit IMMEDIATELY after each production .cls |
| `sfdx/LWCBundle.README.md` | LWC `.html` + `.js` + `.js-meta.xml` together |
| `sfdx/Flow.flow-meta.xml` | Any `.flow-meta.xml` |
| `sfdx/Layout.layout-meta.xml` | Any `.layout-meta.xml` |

## The "metadata-type → has-apiVersion" cheatsheet

REQUIRES `<apiVersion>`:
- ApexClass (`.cls-meta.xml`)
- ApexTrigger (`.trigger-meta.xml`)
- LightningComponentBundle (`.js-meta.xml`)
- AuraDefinitionBundle

REJECTS `<apiVersion>`:
- PermissionSet
- CustomObject
- CustomField
- Layout
- Flow
- CustomLabel / Labels
- ValidationRule

Getting this distinction wrong is the #2 most-frequent deploy failure
in this codebase's history.
