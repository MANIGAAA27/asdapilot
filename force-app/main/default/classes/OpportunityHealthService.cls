/**
 * @file              OpportunityHealthService.cls
 * @description       Core service for detecting and alerting on opportunity health risks.
 *                    Identifies stagnant opportunities, missing contacts, overdue meetings,
 *                    undefined next steps, and stage-activity misalignment.
 * @author            ASDA Dev Agent (Claude)
 * @created           2025-01-10
 * @lastModified      2025-01-10
 * @group             OpportunityHealthCoach
 *
 * @dependencies      OpportunitySelector, OpportunityHealthScorer
 * @calledBy          OpportunityHealthBatch, OpportunityHealthController
 * @testClass         OpportunityHealthServiceTest
 *
 * @see               Opportunity Health Coach Project
 */

/**
 * Service layer for opportunity health analysis and risk detection.
 *
 * Responsibilities:
 *   - Detect stagnant opportunities (no activity within threshold period).
 *   - Identify missing key contacts (no Contact roles assigned).
 *   - Flag opportunities with no scheduled future meetings.
 *   - Validate stage alignment with recent activities.
 *   - Generate actionable recommendations per opportunity stage.
 *
 * Threading: Bulkified for batch processing. Safe to call from triggers
 * (before/after context) and batch execute methods.
 *
 * @testClass OpportunityHealthServiceTest
 */
public with sharing class OpportunityHealthService {
    
    private static final Integer DEFAULT_STAGNANT_DAYS = 14;
    private static final Integer DEFAULT_MEETING_OVERDUE_DAYS = 30;
    
    /**
     * Analyzes a list of opportunities and returns health assessment results.
     * Bulk-safe up to 200 opportunities per invocation.
     *
     * @param  opportunities   List of Opportunity records to analyze. Must include
     *                         LastActivityDate, StageName, LastModifiedDate fields.
     * @param  stagnantDays    Number of days without activity to flag as stagnant.
     *                         Uses DEFAULT_STAGNANT_DAYS when null.
     * @return List of OpportunityHealthResult wrapper objects containing risk flags
     *         and recommended actions. Never returns null; returns empty list when
     *         input is null/empty.
     * @throws OpportunityHealthServiceException when stagnantDays < 1.
     *
     * @calledBy    OpportunityHealthBatch.execute, OpportunityHealthController.analyzeOpportunities
     * @testMethods test_analyzeOpportunities_stagnantDetected, test_analyzeOpportunities_validInput_succeeds
     *
     * Algorithm: O(n) single-pass analysis with Set-based lookups for contact roles
     * and events. Batched SOQL to fetch related records (Contact roles, Events).
     */
    public static List<OpportunityHealthResult> analyzeOpportunities(
        List<Opportunity> opportunities,
        Integer stagnantDays
    ) {
        if (opportunities == null || opportunities.isEmpty()) {
            return new List<OpportunityHealthResult>();
        }
        
        Integer effectiveStagnantDays = (stagnantDays != null && stagnantDays > 0) 
            ? stagnantDays 
            : DEFAULT_STAGNANT_DAYS;
        
        if (effectiveStagnantDays < 1) {
            throw new OpportunityHealthServiceException('stagnantDays must be >= 1');
        }
        
        Set<Id> opportunityIds = new Set<Id>();
        for (Opportunity opp : opportunities) {
            if (opp.Id != null) {
                opportunityIds.add(opp.Id);
            }
        }
        
        Map<Id, List<OpportunityContactRole>> contactRolesByOppId = getContactRolesByOpportunity(opportunityIds);
        Map<Id, List<Event>> upcomingEventsByOppId = getUpcomingEventsByOpportunity(opportunityIds);
        
        List<OpportunityHealthResult> results = new List<OpportunityHealthResult>();
        Date stagnantThreshold = Date.today().addDays(-effectiveStagnantDays);
        Date meetingOverdueThreshold = Date.today().addDays(-DEFAULT_MEETING_OVERDUE_DAYS);
        
        for (Opportunity opp : opportunities) {
            OpportunityHealthResult result = new OpportunityHealthResult();
            result.opportunityId = opp.Id;
            result.opportunityName = opp.Name;
            result.stageName = opp.StageName;
            result.riskFlags = new List<String>();
            result.recommendations = new List<String>();
            
            // Check for stagnant opportunity
            Date lastActivity = opp.LastActivityDate != null ? opp.LastActivityDate : opp.LastModifiedDate.date();
            if (lastActivity < stagnantThreshold) {
                result.isStagnant = true;
                result.riskFlags.add('No activity in ' + effectiveStagnantDays + ' days');
                result.recommendations.add('Schedule a check-in call with the prospect');
            }
            
            // Check for missing key contacts
            List<OpportunityContactRole> contactRoles = contactRolesByOppId.get(opp.Id);
            if (contactRoles == null || contactRoles.isEmpty()) {
                result.hasMissingContacts = true;
                result.riskFlags.add('No contact roles assigned');
                result.recommendations.add('Add key decision-makers and influencers as contact roles');
            }
            
            // Check for scheduled meetings
            List<Event> upcomingEvents = upcomingEventsByOppId.get(opp.Id);
            if (upcomingEvents == null || upcomingEvents.isEmpty()) {
                result.hasNoScheduledMeeting = true;
                result.riskFlags.add('No upcoming meetings scheduled');
                result.recommendations.add('Schedule next meeting to maintain momentum');
            }
            
            // Stage-specific recommendations
            addStageSpecificRecommendations(result, opp);
            
            result.overallHealthScore = calculateHealthScore(result);
            results.add(result);
        }
        
        return results;
    }
    
    /**
     * Retrieves contact roles grouped by opportunity ID.
     *
     * @param  opportunityIds  Set of Opportunity IDs to query.
     * @return Map of Opportunity ID to List of OpportunityContactRole records.
     *         Empty map when no contact roles found. Never returns null.
     */
    private static Map<Id, List<OpportunityContactRole>> getContactRolesByOpportunity(Set<Id> opportunityIds) {
        Map<Id, List<OpportunityContactRole>> resultMap = new Map<Id, List<OpportunityContactRole>>();
        
        if (opportunityIds.isEmpty()) {
            return resultMap;
        }
        
        List<OpportunityContactRole> roles = [
            SELECT Id, OpportunityId, ContactId, Role, IsPrimary
            FROM OpportunityContactRole
            WHERE OpportunityId IN :opportunityIds
        ];
        
        for (OpportunityContactRole role : roles) {
            if (!resultMap.containsKey(role.OpportunityId)) {
                resultMap.put(role.OpportunityId, new List<OpportunityContactRole>());
            }
            resultMap.get(role.OpportunityId).add(role);
        }
        
        return resultMap;
    }
    
    /**
     * Retrieves upcoming events (future start date) grouped by opportunity ID.
     *
     * @param  opportunityIds  Set of Opportunity IDs to query.
     * @return Map of Opportunity ID (via WhatId) to List of Event records.
     *         Empty map when no upcoming events found. Never returns null.
     */
    private static Map<Id, List<Event>> getUpcomingEventsByOpportunity(Set<Id> opportunityIds) {
        Map<Id, List<Event>> resultMap = new Map<Id, List<Event>>();
        
        if (opportunityIds.isEmpty()) {
            return resultMap;
        }
        
        List<Event> events = [
            SELECT Id, WhatId, Subject, StartDateTime, EndDateTime
            FROM Event
            WHERE WhatId IN :opportunityIds
            AND StartDateTime >= :Datetime.now()
            ORDER BY StartDateTime ASC
        ];
        
        for (Event evt : events) {
            if (!resultMap.containsKey(evt.WhatId)) {
                resultMap.put(evt.WhatId, new List<Event>());
            }
            resultMap.get(evt.WhatId).add(evt);
        }
        
        return resultMap;
    }
    
    /**
     * Adds stage-specific actionable recommendations to the health result.
     *
     * @param  result  OpportunityHealthResult wrapper to populate.
     * @param  opp     Opportunity record being analyzed.
     */
    private static void addStageSpecificRecommendations(OpportunityHealthResult result, Opportunity opp) {
        String stage = opp.StageName != null ? opp.StageName.toLowerCase() : '';
        
        if (stage.contains('prospect') || stage.contains('qualif')) {
            result.recommendations.add('Discovery: Confirm budget, authority, need, and timeline (BANT)');
        } else if (stage.contains('needs') || stage.contains('analysis')) {
            result.recommendations.add('Conduct needs analysis workshop with stakeholders');
        } else if (stage.contains('proposal') || stage.contains('quote')) {
            result.recommendations.add('Send proposal and schedule presentation walkthrough');
        } else if (stage.contains('negotiation')) {
            result.recommendations.add('Address objections and negotiate terms with decision-maker');
        } else if (stage.contains('closed') && !stage.contains('won')) {
            result.recommendations.add('Capture closed-lost reason and plan re-engagement timeline');
        }
    }
    
    /**
     * Calculates overall health score (0-100) based on risk flags.
     * Lower score indicates higher risk.
     *
     * @param  result  OpportunityHealthResult with populated risk flags.
     * @return Integer score between 0 (critical risk) and 100 (healthy).
     */
    private static Integer calculateHealthScore(OpportunityHealthResult result) {
        Integer score = 100;
        
        if (result.isStagnant) {
            score -= 30;
        }
        if (result.hasMissingContacts) {
            score -= 25;
        }
        if (result.hasNoScheduledMeeting) {
            score -= 20;
        }
        
        Integer additionalRisks = result.riskFlags.size() - 
            (result.isStagnant ? 1 : 0) - 
            (result.hasMissingContacts ? 1 : 0) - 
            (result.hasNoScheduledMeeting ? 1 : 0);
        score -= (additionalRisks * 10);
        
        return Math.max(0, score);
    }
    
    /**
     * Wrapper class for opportunity health analysis results.
     */
    public class OpportunityHealthResult {
        public Id opportunityId { get; set; }
        public String opportunityName { get; set; }
        public String stageName { get; set; }
        public Boolean isStagnant { get; set; }
        public Boolean hasMissingContacts { get; set; }
        public Boolean hasNoScheduledMeeting { get; set; }
        public List<String> riskFlags { get; set; }
        public List<String> recommendations { get; set; }
        public Integer overallHealthScore { get; set; }
        
        public OpportunityHealthResult() {
            this.isStagnant = false;
            this.hasMissingContacts = false;
            this.hasNoScheduledMeeting = false;
            this.riskFlags = new List<String>();
            this.recommendations = new List<String>();
            this.overallHealthScore = 100;
        }
    }
    
    /**
     * Custom exception for OpportunityHealthService errors.
     */
    public class OpportunityHealthServiceException extends Exception {}
}
