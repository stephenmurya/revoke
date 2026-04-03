package com.crescence.revoke

import android.graphics.drawable.Drawable

enum class BlockState {
    TIME_BLOCK,
    USAGE_LIMIT_REACHED,
    WINDOW_CLOSED,
}

data class BlockStatChip(
    val label: String,
    val value: String,
)

data class BlockPresentation(
    val appName: String,
    val packageName: String,
    val appIcon: Drawable?,
    val blockState: BlockState,
    val regimeName: String,
    val headlineAccent: String,
    val headlineMain: String,
    val explanatoryLine: String,
    val secondaryLine: String,
    val contextualStats: List<BlockStatChip>,
    val hasSquad: Boolean,
    val attemptsToday: Int = 0,
    val stats: List<BlockStatChip> = emptyList(),
)
