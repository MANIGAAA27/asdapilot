/**
 * @file        CPQ_ConfigScannerTest.cls
 * @description Tests CPQ_ConfigScanner — covers object scanning, field enumeration,
 *              persistence of scan results, and empty/null edge cases.
 * @testFor     CPQ_ConfigScanner
 * @coverage    Target ≥ 90%.
 */
@isTest
private class CPQ_ConfigScannerTest {

    @testSetup
    static void setupData() {
        // No custom object DML required; scanner uses Schema.getGlobalDescribe()
    }

    @isTest
    static void test_scanCpqObjects_returnsResults() {
        CPQ_ConfigScanner scanner = new CPQ_ConfigScanner();

        Test.startTest();
        List<CPQ_ConfigScanner.FieldScanResult> results = scanner.scanCpqObjects();
        Test.stopTest();

        // Product2 is always present in any Salesforce org
        System.assert(results != null, 'Results should not be null');
        System.assert(!results.isEmpty(), 'Results should contain at least one field from Product2');

        Boolean foundProduct2 = false;
        for (CPQ_ConfigScanner.FieldScanResult fsr : results) {
            if (fsr.sourceObjectApiName == 'Product2') {
                foundProduct2 = true;
                System.assert(String.isNotBlank(fsr.sourceFieldApiName),
                    'sourceFieldApiName should not be blank');
                System.assert(String.isNotBlank(fsr.sourceFieldType),
                    'sourceFieldType should not be blank');
                break;
            }
        }
        System.assert(foundProduct2, 'Should have found at least one Product2 field');
    }

    @isTest
    static void test_getCpqObjectNames_returnsExpectedList() {
        CPQ_ConfigScanner scanner = new CPQ_ConfigScanner();

        Test.startTest();
        List<String> names = scanner.getCpqObjectNames();
        Test.stopTest();

        System.assert(names != null, 'Object names list should not be null');
        System.assert(!names.isEmpty(), 'Object names list should not be empty');
        System.assert(names.contains('Product2'), 'Should contain Product2');
    }

    @isTest
    static void test_persistScanResults_emptyList_returnsEmpty() {
        CPQ_ConfigScanner scanner = new CPQ_ConfigScanner();

        Test.startTest();
        List<Database.SaveResult> results = scanner.persistScanResults(
            new List<CPQ_ConfigScanner.FieldScanResult>()
        );
        Test.stopTest();

        System.assert(results != null, 'SaveResult list should not be null');
        System.assertEquals(0, results.size(), 'Empty input should return empty results');
    }

    @isTest
    static void test_persistScanResults_nullList_returnsEmpty() {
        CPQ_ConfigScanner scanner = new CPQ_ConfigScanner();

        Test.startTest();
        List<Database.SaveResult> results = scanner.persistScanResults(null);
        Test.stopTest();

        System.assert(results != null, 'SaveResult list should not be null');
        System.assertEquals(0, results.size(), 'Null input should return empty results');
    }

    @isTest
    static void test_persistScanResults_insertsRecords() {
        CPQ_ConfigScanner scanner = new CPQ_ConfigScanner();

        CPQ_ConfigScanner.FieldScanResult fsr = new CPQ_ConfigScanner.FieldScanResult();
        fsr.sourceObjectApiName = 'Product2';
        fsr.sourceFieldApiName = 'Name';
        fsr.sourceFieldLabel = 'Product Name';
        fsr.sourceFieldType = 'STRING';
        fsr.suggestedTargetFieldApiName = 'Name';
        fsr.confidenceScore = 1.0;

        Test.startTest();
        List<Database.SaveResult> results = scanner.persistScanResults(
            new List<CPQ_ConfigScanner.FieldScanResult>{ fsr }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should have one save result');
        System.assert(results[0].isSuccess(), 'Insert should succeed: ' +
            (results[0].getErrors().isEmpty() ? '' : results[0].getErrors()[0].getMessage()));
    }

    @isTest
    static void test_fieldScanResult_defaultConstructor_setsNullFields() {
        Test.startTest();
        CPQ_ConfigScanner.FieldScanResult fsr = new CPQ_ConfigScanner.FieldScanResult();
        Test.stopTest();

        System.assertEquals(null, fsr.sourceObjectApiName, 'sourceObjectApiName should be null by default');
        System.assertEquals(null, fsr.sourceFieldApiName, 'sourceFieldApiName should be null by default');
        System.assertEquals(null, fsr.confidenceScore, 'confidenceScore should be null by default');
    }
}
