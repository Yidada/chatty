package ai.chatty.core.model

import kotlinx.serialization.Serializable

// Multica server/internal/handler/auth.go LoginResponse, SendCode, VerifyCode.
@Serializable data class CodeRequest(val email: String)
@Serializable data class VerifyRequest(val email: String, val code: String)
@Serializable data class LoginResponse(val token: String)
// Multica server/internal/handler/workspace.go WorkspaceResponse.
@Serializable data class Workspace(val id: String, val slug: String, val name: String)
