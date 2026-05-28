trigger LeadToContactTrigger on Lead (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        new LeadToContactHandler().handleLeadInsert(Trigger.new);
    }
}