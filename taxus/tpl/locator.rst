@require(href, status, global_id, last_seen, date_added, date_updated, deleted, date_deleted )
<@href> #@global_id
@if status:
    :status: @status
@end
    :added: @date_added.strftime('%m/%d/%Y %I:%M %p')
@if last_seen:
    :last-seen: @last_seen.strftime('%m/%d/%Y %I:%M %p')
@end
@if date_updated:
    :updated: @date_updated.strftime('%m/%d/%Y %I:%M %p')
@end
@if deleted:
    :deleted: @date_deleted.strftime('%m/%d/%Y %I:%M %p')
@end

