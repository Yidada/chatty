package ai.chatty.feature.chat

import org.commonmark.node.*
import org.commonmark.parser.Parser
import org.junit.Assert.*
import org.junit.Test

class NativeNavigationTest {
    private val base = "https://api.multica.ai/"

    @Test fun multicaAndApiLinksNeverLeaveTheApp() {
        listOf("https://multica.ai/w/settings", "HTTPS://WWW.MULTICA.AI./w/chat",
            "//multica.ai/w/issue/I-1", "https://app.multica.ai/x", "/api/issues/i1",
            "https://api.multica.ai:443/api/attachments/a/download").forEach {
            assertNull(it, externalContentLink(it, base))
        }
        assertNull(externalContentLink("/w/settings", "https://multica.example.test/"))
    }

    @Test fun ordinaryReferencesRemainAvailableButInvalidSchemesDoNot() {
        assertEquals("https://example.org/doc", externalContentLink("https://example.org/doc", base))
        assertEquals("https://multica.ai.example.org/", externalContentLink("https://multica.ai.example.org/", base))
        listOf("javascript:alert(1)", "intent://multica.ai", "file:///tmp/a", "https://user@multica.ai/", "http://[").forEach {
            assertNull(externalContentLink(it, base))
        }
        // Fetching native content must remain possible even when browser navigation is removed.
        assertEquals("https://api.multica.ai/api/image", safeWebLink("/api/image", base))
    }

    @Test fun markdownKeepsLabelsFormattingAndImagesWithoutInternalClickTargets() {
        val doc = Parser.builder().build().parse("[**项目**](https://multica.ai/w/projects) [详情](/w/issue/I-1) [资料](https://example.org/doc) ![图片](/api/image)")
        removeAppLinks(doc, base)
        val links = mutableListOf<String>()
        val text = mutableListOf<String>()
        var emphasis = 0
        var images = 0
        doc.accept(object : AbstractVisitor() {
            override fun visit(link: Link) { links += link.destination; visitChildren(link) }
            override fun visit(node: Text) { text += node.literal }
            override fun visit(node: StrongEmphasis) { emphasis++; visitChildren(node) }
            override fun visit(node: Image) { images++; visitChildren(node) }
        })
        assertEquals(listOf("https://example.org/doc"), links)
        assertTrue(text.containsAll(listOf("项目", "详情", "资料", "图片")))
        assertEquals(1, emphasis)
        assertEquals(1, images)
    }
}
