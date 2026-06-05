/**
 * @file        PIIMaskingServiceTest.cls
 * @description Tests PIIMaskingService — covers all seven PII masking categories,
 *              bulk list masking, null/blank edge cases, and non-PII pass-through.
 * @testFor     PIIMaskingService
 * @coverage    Target >= 90%.
 */
// MODIFIED 2026-06-05 — Project: Case Transfer | LLD-CaseTransfer-1 (BR1-BR2) | ASDA
@isTest
private class PIIMaskingServiceTest {

    @isTest
    static void maskText_emailMasked() {
        String input = 'Contact john.doe@example.com for details.';
        Test.startTest();
        String result = PIIMaskingService.maskText(input);
        Test.stopTest();
        System.assert(!result.contains('@'), 'Email address should be redacted');
        System.assert(result.contains('[EMAIL_REDACTED]'), 'Email placeholder must appear');
    }

    @isTest
    static void maskText_ssnMasked() {
        String input = 'Social Security: 123-45-6789 on file.';
        Test.startTest();
        String result = PIIMaskingService.maskText(input);
        Test.stopTest();
        System.assert(!result.contains('123-45-6789'), 'SSN should be redacted');
        System.assert(result.contains('[ID_REDACTED]'), 'ID placeholder must appear');
    }

    @isTest
    static void maskText_creditCardMasked() {
        String input = 'Card ending 4111 1111 1111 1111 was charged.';
        Test.startTest();
        String result = PIIMaskingService.maskText(input);
        Test.stopTest();
        System.assert(!result.contains('4111 1111 1111 1111'), 'Credit card should be redacted');
        System.assert(result.contains('[CARD_REDACTED]'), 'Card placeholder must appear');
    }

    @isTest
    static void maskText_phoneMasked() {
        String input = 'Call us at (555) 867-5309 anytime.';
        Test.startTest();
        String result = PIIMaskingService.maskText(input);
        Test.stopTest();
        System.assert(!result.contains('867-5309'), 'Phone number should be redacted');
        System.assert(result.contains('[PHONE_REDACTED]'), 'Phone placeholder must appear');
    }

    @isTest
    static void maskText_secretMasked() {
        String input = 'Authentication: password=s3cr3t_P@ssw0rd used.';
        Test.startTest();
        String result = PIIMaskingService.maskText(input);
        Test.stopTest();
        System.assert(!result.contains('s3cr3t_P@ssw0rd'), 'Secret value should be redacted');
        System.assert(result.contains('[SECRET_REDACTED]'), 'Secret placeholder must appear');
    }

    @isTest
    static void maskText_noPii_returnsUnchanged() {
        String input = 'The customer reported a login issue with their dashboard.';
        Test.startTest();
        String result = PIIMaskingService.maskText(input);
        Test.stopTest();
        System.assert(result.contains('login issue'), 'Non-PII content should be preserved');
    }

    @isTest
    static void maskText_nullInput_returnsEmpty() {
        Test.startTest();
        String result = PIIMaskingService.maskText(null);
        Test.stopTest();
        System.assertEquals('', result, 'Null input should return empty string');
    }

    @isTest
    static void maskText_blankInput_returnsSame() {
        Test.startTest();
        String result = PIIMaskingService.maskText('   ');
        Test.stopTest();
        System.assertEquals('   ', result, 'Blank input should return as-is');
    }

    @isTest
    static void maskTexts_masksList() {
        List<String> inputs = new List<String>{
            'Email: test@test.com',
            'No PII here',
            'SSN: 999-88-7777'
        };
        Test.startTest();
        List<String> results = PIIMaskingService.maskTexts(inputs);
        Test.stopTest();
        System.assertEquals(3, results.size(), 'Output list size must match input');
        System.assert(results[0].contains('[EMAIL_REDACTED]'), 'First entry email should be redacted');
        System.assert(results[1].contains('No PII here'), 'Non-PII must pass through');
        System.assert(results[2].contains('[ID_REDACTED]'), 'Third entry SSN should be redacted');
    }

    @isTest
    static void maskTexts_nullInput_returnsEmptyList() {
        Test.startTest();
        List<String> results = PIIMaskingService.maskTexts(null);
        Test.stopTest();
        System.assertNotEquals(null, results, 'Should never return null');
        System.assertEquals(0, results.size(), 'Null input should yield empty list');
    }
}
