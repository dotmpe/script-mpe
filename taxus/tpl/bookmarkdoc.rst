@require(name, location, tags, date_added, date_updated, deleted, date_deleted, public, extended )
`@name <@location['href']>`_
@if tags:
    :tags: @tags
@end
    :added: @date_added.strftime('%m/%d/%Y %I:%M %p')
@if date_updated:
    :updated: @date_updated.strftime('%m/%d/%Y %I:%M %p')
@end
@if deleted:
    :deleted: @date_deleted.strftime('%m/%d/%Y %I:%M %p')
@end
@if public:
    :public: @public
@end
@if extended:

    @extended
@end
