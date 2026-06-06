/**
 * @file              ValidationException.cls
 * @description       Custom exception class for validation errors within the ARMT application.
 *                    Thrown when pre-migration validation checks fail or encounter blockers.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             ARMT_Exceptions
 *
 * @dependencies      (none)
 * @calledBy          ARMT_ConfigurationScanner
 * @testClass         ARMT_ConfigurationScannerTest
 *
 * @see               HLD-ARMT-V1.0 Section 3.3
 */

/**
 * Custom exception for validation errors.
 * Thrown when pre-migration validation checks fail or encounter blockers.
 */
public with sharing class ValidationException extends Exception {
}
