/**
 * @file        AppException.cls
 * @project     Account Deactivation
 * @lld         LLD - Intelligent Suppression Engine for Inactive Records in Lookups, Reports, Flows, Lightning, and API Contexts (draft)
 * @createdBy   ASDA Dev Agent
 * @created     2026-06-05
 */
/**
 * @file              AppException.cls
 * @description       Custom exception type for the Data Lifecycle Governance platform.
 *                    Used to distinguish application-level errors from system exceptions.
 * @author            ASDA Dev Agent
 * @created           2025-01-23
 * @lastModified      2025-01-23
 * @group             CoreFramework
 *
 * @dependencies      None
 * @calledBy          ErrorLogger, all service classes
 * @testClass         ErrorLoggerTest (tested alongside ErrorLogger)
 *
 * @see               LLD Account Deactivation Platform
 */

/**
 * Custom exception for application-level errors in the governance platform.
 * Thrown via ErrorLogger.throwAppException() for controlled error flows.
 *
 * @testClass ErrorLoggerTest
 */
public class AppException extends Exception {
}
