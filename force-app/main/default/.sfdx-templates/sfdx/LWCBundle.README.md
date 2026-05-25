# LWC Bundle Template

An LWC bundle lives under `force-app/main/default/lwc/<componentName>/`
and MUST contain ALL THREE of these files with the same basename:

  <componentName>.html
  <componentName>.js
  <componentName>.js-meta.xml

Missing any one triggers preflight `INCOMPLETE_LWC_BUNDLE` (SFDX Rule 3).

Apex controller references — Rule 8 in SFDX Structure Rules:
every `@salesforce/apex/ClassName.methodName` import requires
`force-app/main/default/classes/ClassName.cls` in this same deploy
package with `@AuraEnabled` on the method.

## componentName.html
```html
<template>
    <lightning-card title="My Component" icon-name="custom:custom19">
        <template if:true={records.data}>
            <ul class="slds-p-around_medium">
                <template for:each={records.data} for:item="r">
                    <li key={r.Id}>{r.Name} — {r.My_Field__c}</li>
                </template>
            </ul>
        </template>
        <template if:true={records.error}>
            <p class="slds-text-color_error slds-p-around_medium">Error loading records.</p>
        </template>
    </lightning-card>
</template>
```

## componentName.js
```js
import { LightningElement, wire } from 'lwc';
// Each @salesforce/apex import below requires the matching ClassName.cls
// in this deploy package with @AuraEnabled on the method.
import getRecentRecords from '@salesforce/apex/MyController.getRecentRecords';

export default class MyComponent extends LightningElement {
    @wire(getRecentRecords, { recordLimit: 10 })
    records;
}
```

## componentName.js-meta.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <!-- LightningComponentBundle REQUIRES <apiVersion>. (Distinct from PermissionSet/CustomObject which reject it.) -->
    <apiVersion>62.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__AppPage</target>
        <target>lightning__RecordPage</target>
        <target>lightning__HomePage</target>
    </targets>
</LightningComponentBundle>
```

Root element is `<LightningComponentBundle>` — NEVER `<LightningElementBundle>` (common LLM mistake).