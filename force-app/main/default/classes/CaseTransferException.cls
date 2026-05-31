/**
 * @file              CaseTransferException.cls
 * @description       Base custom exception for all case transfer-related errors.
 *                    Provides a typed hierarchy root for ValidationException and
 *                    AttachmentException so callers can catch the base type when needed.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-30
 * @lastModified      2026-05-30
 * @group             CaseTransfer
 *
 * @dependencies      (none in this changeset)
 * @calledBy          CaseTransferService, CaseTransferDomain, CaseTransferController,
 *                    CaseTransferAPI
 * @testClass         CaseTransferServiceTest
 *
 * @see               LLD Case Transfer Flow — Error Handling Design §8
 */

/**
 * Base exception for all case transfer operations.
 *
 * Responsibilities:
 *   - Serve as a typed root for ValidationException and AttachmentException.
 *   - Carry user-friendly messages for display in LWC and Flow fault paths.
 *
 * @testClass CaseTransferServiceTest
 */
public with sharing class CaseTransferException extends Exception {
}
