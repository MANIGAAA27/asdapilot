/**
 * @file              AttachmentException.cls
 * @description       Custom exception managing file upload errors during the attachment
 *                    process of case transfer. Extends CaseTransferException for typed
 *                    exception handling in callers.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-30
 * @lastModified      2026-05-30
 * @group             CaseTransfer
 *
 * @dependencies      CaseTransferException
 * @calledBy          CaseTransferService, CaseTransferDomain
 * @testClass         CaseTransferServiceTest
 *
 * @see               LLD Case Transfer Flow — Error Handling Design §8
 */

/**
 * Thrown when file attachment validation fails during case transfer.
 *
 * Responsibilities:
 *   - Distinguish file-related failures from field validation failures.
 *   - Carry specific messages (e.g., "No log files attached") for LWC display.
 *
 * @testClass CaseTransferServiceTest
 */
public with sharing class AttachmentException extends CaseTransferException {
}
