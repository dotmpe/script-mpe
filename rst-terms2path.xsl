<?xml version="1.0" ?>
<!-- from docutuil-ext.mpe; edited in script-mpe -->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="/"><xsl:apply-templates select="//document/definition_list" /></xsl:template><xsl:template match="*/definition_list"><xsl:apply-templates select="definition_list_item" /></xsl:template><xsl:template match="*/definition_list_item"><xsl:choose><xsl:when test="matches(term, '^[A-Za-z0-9_-]+$')">/<xsl:value-of select="term"/></xsl:when><xsl:otherwise>/&quot;<xsl:value-of select="term"/>&quot;</xsl:otherwise></xsl:choose><xsl:apply-templates select="definition/definition_list" />/..</xsl:template></xsl:stylesheet>
