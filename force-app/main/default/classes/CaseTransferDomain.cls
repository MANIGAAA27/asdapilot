/**
 * @file              CaseTransferDomain.cls
 * @description       Domain class encapsulating business rule enforcement and data processing
 *                    for case transfer operations. Wraps a single Case record and exposes
 *                    deterministic validation methods used by CaseTransferService.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-30
 * @lastModified      2026-05-30
 * @group             CaseTransfer
 *
 * @dependencies      CaseTransferException, ValidationException, ErrorLogger
 * @calledBy          CaseTransferService
 * @testClass         CaseTransferDomainTest
 *
 * @see               LLD Case Transfer Flow — Apex Class Design §3
 */

/**
 * Domain model for Case transfer business rules.
 *
 * Responsibilities:
 *   - Validate required field presence on a Case record.
 *   - Enforce minimum character length for troubleshooting documentation.
 *   - Check content document attachment count.
 *   - Prepare Case update data for persistence by CaseTransferService.
 *
 * @testClass CaseTransferDomainTest
 */
public with sharing class CaseTransferDomain {
    
    private Case caseRecord;
    private static final Integer MIN_TROUBLESHOOTING_LENGTH = 20;

    /**
     * Constructor accepting a Case record.
     * @param caseRecord Case to validate and process
     */
    public CaseTransferDomain(Case caseRecord) {
        this.caseRecord = caseRecord;
    }

    /**
     * Validates all required fields are present and meet minimum requirements.
     * @param contentDocumentIds List of attached file IDs
     * @throws ValidationException if any validation fails
     */
    public void validateTransferRequirements(List<String> contentDocumentIds) {
        try {
            validateAttachments(contentDocumentIds);
            validateReproductionSteps();
            validateTroubleshootingSteps();
        } catch (ValidationException ex) {
            ErrorLogger.logException(ex, 'CaseTransferDomain.validateTransferRequirements');
            throw ex;
        } catch (Exception ex) {
            ErrorLogger.logException(ex, 'CaseTransferDomain.validateTransferRequirements');
            throw new ValidationException(System.Label.CaseTransfer_ErrorMessages);
        }
    }

    /**
     * Validates at least one file is attached.
     * @param contentDocumentIds List of content document IDs
     * @throws ValidationException if no files attached
     */
    private void validateAttachments(List<String> contentDocumentIds) {
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            throw new ValidationException(System.Label.CaseTransfer_MissingFiles);
        }
    }

    /**
     * Validates reproduction steps field is populated.
     * @throws ValidationException if reproduction steps blank
     */
    private void validateReproductionSteps() {
        if (String.isBlank(caseRecord.Reproduction_Steps__c)) {
            throw new ValidationException(System.Label.CaseTransfer_MissingSteps);
        }
    }

    /**
     * Validates troubleshooting steps meet minimum length requirement.
     * @throws ValidationException if troubleshooting detail insufficient
     */
    private void validateTroubleshootingSteps() {
        if (String.isBlank(caseRecord.Troubleshooting_Steps_Taken__c) ||
            caseRecord.Troubleshooting_Steps_Taken__c.length() < MIN_TROUBLESHOOTING_LENGTH) {
            throw new ValidationException(System.Label.CaseTransfer_InsufficientDetail);
        }
    }

    /**
     * Prepares the Case record for update after successful validation.
     * @return Case record ready for DML
     */
    public Case prepareForTransfer() {
        caseRecord.Transferred_to_Engineering__c = true;
        return caseRecord;
    }
}
