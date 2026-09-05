package ai.chatty.core.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val Light = lightColorScheme(
    primary = Color(0xFF365E50), onPrimary = Color.White,
    primaryContainer = Color(0xFFE1EBE4), onPrimaryContainer = Color(0xFF203D32),
    secondary = Color(0xFF56645C), onSecondary = Color.White,
    secondaryContainer = Color(0xFFE8ECE7), onSecondaryContainer = Color(0xFF34473D),
    tertiary = Color(0xFF78664C), onTertiary = Color.White,
    tertiaryContainer = Color(0xFFF2EADB), onTertiaryContainer = Color(0xFF4D402C),
    background = Color(0xFFF6F7F4), onBackground = Color(0xFF202521),
    surface = Color(0xFFFFFFFF), onSurface = Color(0xFF202521),
    surfaceVariant = Color(0xFFEBEEE8), onSurfaceVariant = Color(0xFF656D65),
    surfaceTint = Color(0xFF365E50), outline = Color(0xFF818A80), outlineVariant = Color(0xFFE2E6DF),
    inverseSurface = Color(0xFF28332D), inverseOnSurface = Color(0xFFF1F4EF),
    error = Color(0xFFAD3434), onError = Color.White, errorContainer = Color(0xFFFBE5E2), onErrorContainer = Color(0xFF752621)
)
private val Dark = darkColorScheme(
    primary = Color(0xFFA9CDB8), onPrimary = Color(0xFF193A2C),
    primaryContainer = Color(0xFF2B4135), onPrimaryContainer = Color(0xFFD3EADB),
    secondary = Color(0xFFB5C6B8), onSecondary = Color(0xFF233329),
    secondaryContainer = Color(0xFF303C33), onSecondaryContainer = Color(0xFFD4DFD4),
    tertiary = Color(0xFFD5C1A1), onTertiary = Color(0xFF3C3020),
    tertiaryContainer = Color(0xFF463E31), onTertiaryContainer = Color(0xFFEFE0C8),
    background = Color(0xFF141815), onBackground = Color(0xFFE5EAE2),
    surface = Color(0xFF1E241F), onSurface = Color(0xFFE5EAE2),
    surfaceVariant = Color(0xFF29312A), onSurfaceVariant = Color(0xFFABB5AA),
    surfaceTint = Color(0xFFA9CDB8), outline = Color(0xFF788476), outlineVariant = Color(0xFF343F35),
    inverseSurface = Color(0xFFDFE8DD), inverseOnSurface = Color(0xFF273328),
    error = Color(0xFFF3ABA5), onError = Color(0xFF601E1C), errorContainer = Color(0xFF482725), onErrorContainer = Color(0xFFFFDAD6)
)
private val Type = Typography(
    headlineLarge = TextStyle(fontSize = 32.sp, lineHeight = 40.sp, fontWeight = FontWeight.SemiBold, letterSpacing = (-.8).sp),
    headlineMedium = TextStyle(fontSize = 28.sp, lineHeight = 36.sp, fontWeight = FontWeight.SemiBold, letterSpacing = (-.6).sp),
    headlineSmall = TextStyle(fontSize = 24.sp, lineHeight = 32.sp, fontWeight = FontWeight.SemiBold, letterSpacing = (-.4).sp),
    titleLarge = TextStyle(fontSize = 24.sp, lineHeight = 32.sp, fontWeight = FontWeight.SemiBold, letterSpacing = (-.4).sp),
    titleMedium = TextStyle(fontSize = 16.sp, lineHeight = 24.sp, fontWeight = FontWeight.SemiBold),
    titleSmall = TextStyle(fontSize = 14.sp, lineHeight = 20.sp, fontWeight = FontWeight.Medium),
    bodyLarge = TextStyle(fontFamily = FontFamily.SansSerif, fontSize = 16.sp, lineHeight = 26.sp),
    bodyMedium = TextStyle(fontSize = 14.sp, lineHeight = 22.sp),
    bodySmall = TextStyle(fontSize = 12.sp, lineHeight = 18.sp),
    labelLarge = TextStyle(fontSize = 14.sp, lineHeight = 20.sp, fontWeight = FontWeight.Medium),
    labelMedium = TextStyle(fontSize = 12.sp, lineHeight = 18.sp, fontWeight = FontWeight.Medium),
    labelSmall = TextStyle(fontSize = 11.sp, lineHeight = 16.sp, fontWeight = FontWeight.Medium)
)

@Composable
fun ChattyTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) Dark else Light,
        typography = Type,
        shapes = Shapes(extraSmall = RoundedCornerShape(8.dp), small = RoundedCornerShape(12.dp), medium = RoundedCornerShape(18.dp), large = RoundedCornerShape(24.dp), extraLarge = RoundedCornerShape(28.dp)),
        content = content
    )
}

@Composable
fun ActionIcon(icon: ImageVector, label: String, onClick: () -> Unit, enabled: Boolean = true, modifier: Modifier = Modifier) {
    IconButton(onClick = onClick, enabled = enabled, modifier = modifier.size(48.dp)) {
        Icon(icon, label, Modifier.size(22.dp))
    }
}

@Composable
fun PageHeader(title: String, subtitle: String? = null, backLabel: String? = null, back: (() -> Unit)? = null, actions: @Composable RowScope.() -> Unit = {}) {
    Row(Modifier.fillMaxWidth().padding(start = if (back == null) 24.dp else 8.dp, end = 16.dp, top = 16.dp, bottom = 16.dp), verticalAlignment = Alignment.CenterVertically) {
        if (back != null) ActionIcon(Icons.AutoMirrored.Outlined.ArrowBack, backLabel ?: "返回", back)
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleLarge, maxLines = 2, overflow = TextOverflow.Ellipsis)
            subtitle?.let { Text(it, Modifier.padding(top = 4.dp), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall) }
        }
        actions()
    }
}

@Composable
fun GlyphBadge(icon: ImageVector, modifier: Modifier = Modifier, prominent: Boolean = false) {
    Surface(modifier.size(44.dp), shape = RoundedCornerShape(14.dp), color = if (prominent) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant) {
        Box(contentAlignment = Alignment.Center) { Icon(icon, null, Modifier.size(22.dp), tint = MaterialTheme.colorScheme.primary) }
    }
}

@Composable
fun StatusPill(text: String) {
    Surface(color = MaterialTheme.colorScheme.secondaryContainer, shape = CircleShape) {
        Text(text, Modifier.padding(horizontal = 10.dp, vertical = 4.dp), color = MaterialTheme.colorScheme.onSecondaryContainer, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
fun SectionLabel(text: String) {
    Text(text, Modifier.padding(start = 4.dp, top = 12.dp, bottom = 8.dp), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
}
