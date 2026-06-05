/**
 * @file              PIIMaskingService.cls
 * @description       Applies PII redaction to text strings before they are sent to
 *                    the LLM service or persisted in SummaryText__c. Implements
 *                    SEC-12, SEC-13, TR-05, and TR-06. Regex patterns cover the seven
 *                    categories defined in HLD Section 5.4 and are subject to
 *                    security-team peer review prior to production deployment.
 * @author            ASDA Dev Agent
 * @created           2026-06-05
 * @lastModified      2026-06-05
 * @group             CaseTransfer
 *
 * @dependencies      (none)
 * @calledBy          CaseSummaryGeneratorQueueable
 * @testClass         PIIMaskingServiceTest
 *
 * @see               HLD Section 5.4 — PII Masking Design
 */
// MODIFIED 2026-06-05 — Project: Case Transfer | LLD-CaseTransfer-1 (BR1-BR2) | ASDA
public with sharing class PIIMaskingService {

    /** Replacement tokens for each PII category. */
    private static final String EMAIL_REDACTED   = '[EMAIL_REDACTED]';
    private static final String PHONE_REDACTED   = '[PHONE_REDACTED]';
    private static final String ID_REDACTED      = '[ID_REDACTED]';
    private static final String CARD_REDACTED    = '[CARD_REDACTED]';
    private static final String SECRET_REDACTED  = '[SECRET_REDACTED]';
    private static final String ADDRESS_REDACTED = '[ADDRESS_REDACTED]';

    /**
     * Masks all detectable PII in the provided text.
     * Applies patterns in order: email → SSN → payment cards → secrets → phone → address.
     * Earlier passes are more precise; later passes are broader and may overlap.
     *
     * @param  rawText  Input text that may contain PII. Null or blank returns as-is.
     * @return          Text with all matched PII replaced by category placeholders.
     *                  Never returns null; returns empty string for null input.
     *
     * @calledBy    CaseSummaryGeneratorQueueable
     * @testMethods PIIMaskingServiceTest.maskText_emailMasked,
     *              PIIMaskingServiceTest.maskText_ssnMasked,
     *              PIIMaskingServiceTest.maskText_creditCardMasked,
     *              PIIMaskingServiceTest.maskText_phoneMasked,
     *              PIIMaskingServiceTest.maskText_secretMasked,
     *              PIIMaskingServiceTest.maskText_nullReturnsEmpty,
     *              PIIMaskingServiceTest.maskText_blankReturnsSame
     */
    public static String maskText(String rawText) {
        if (String.isBlank(rawText)) {
            return rawText == null ? '' : rawText;
        }
        String result = rawText;

        // 1. Email addresses: local@domain.tld
        result = Pattern.compile('[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}')
                        .matcher(result).replaceAll(EMAIL_REDACTED);

        // 2. US Social Security Numbers: ###-##-####
        result = Pattern.compile('\\b\\d{3}-\\d{2}-\\d{4}\\b')
                        .matcher(result).replaceAll(ID_REDACTED);

        // 3. Payment card numbers — 16-digit (Visa/MC/Discover)
        result = Pattern.compile('\\b\\d{4}[ \\-]?\\d{4}[ \\-]?\\d{4}[ \\-]?\\d{4}\\b')
                        .matcher(result).replaceAll(CARD_REDACTED);

        // 4. Amex — 15-digit starting with 34 or 37
        result = Pattern.compile('\\b3[47]\\d{13}\\b')
                        .matcher(result).replaceAll(CARD_REDACTED);

        // 5. Secrets, passwords, tokens
        result = Pattern.compile('(?i)(password|token|api[_\\-]?key|secret)[\\s:=]+\\S+')
                        .matcher(result).replaceAll(SECRET_REDACTED);

        // 6. North American phone numbers
        result = Pattern.compile(
                        '(?:\\+?1[\\s.\\-]?)?\\(?\\d{3}\\)?[\\s.\\-]?\\d{3}[\\s.\\-]?\\d{4}'
                  ).matcher(result).replaceAll(PHONE_REDACTED);

        // 7. Street addresses — number followed by street name + type keyword
        result = Pattern.compile(
                        '\\b\\d{1,5}\\s+\\w+(?:\\s+\\w+){0,2}\\s+' +
                        '(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Way|Place|Pl)\\b'
                  ).matcher(result).replaceAll(ADDRESS_REDACTED);

        return result;
    }

    /**
     * Convenience method to mask PII in all strings within a list.
     *
     * @param  rawTexts  List of raw text strings. Null list returns empty list.
     * @return           New list with each element passed through maskText().
     *
     * @calledBy    CaseSummaryGeneratorQueueable
     * @testMethods PIIMaskingServiceTest.maskTexts_masksList,
     *              PIIMaskingServiceTest.maskTexts_nullReturnsEmpty
     */
    public static List<String> maskTexts(List<String> rawTexts) {
        List<String> masked = new List<String>();
        if (rawTexts == null) {
            return masked;
        }
        for (String t : rawTexts) {
            masked.add(maskText(t));
        }
        return masked;
    }
}
