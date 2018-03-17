# RDF schemas in notation3 format
#
SCHEMAS_RDF := rdf owl rdfs dcam dc foaf skos

RDF_CONV_N3_CURL := curl -sSf http://rdf-translator.appspot.com/convert/detect/n3/
get_cdn_url = $(shell . .cdn.sh && printf -- "$$$2_$1")

define fetch-n3
	URL="$(call get_cdn_url,n3_http_packages,$(shell basename $@ .n3))"; \
	test -n "$$URL" || exit 1
endef
define convert-n3
	URL="$(call get_cdn_url,rdfxml_http_packages,$(shell basename $@ .n3))"; \
	test -n "$$URL" || exit 1; \
	$(RDF_CONV_N3_CURL)$$URL | sed 's/\<'$(shell basename $@)':/:/g' >$@
endef
define get-n3
	$(fetch-n3) && exit 0 || true; \
	$(convert-n3)
endef

schema/%.n3:
	@$(get-n3)

DEP += $(addprefix schema/,$(addsuffix .n3,$(SCHEMAS_RDF)))

DEP += $/.cdn.sh

$/.cdn.sh: $/cdn.yml
	jsotk dump -Iyml -Ofkv $^ > $@
