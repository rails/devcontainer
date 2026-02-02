# frozen_string_literal: true

# Shared console output helpers
#
# Provides ANSI color codes and emoji constants for consistent
# formatted output across all classes.
module Console
  # ANSI color codes
  COLORS = {
    reset: "\e[0m",
    green: "\e[32m",
    blue: "\e[34m",
    yellow: "\e[33m",
    red: "\e[31m",
    cyan: "\e[36m",
    magenta: "\e[35m"
  }.freeze

  # Emoji helpers
  EMOJI = {
    # General
    search: "🔍",
    edit: "📝",
    check: "✅",
    update: "🔄",
    info: "ℹ️",
    party: "🎉",
    file: "📄",
    bulb: "💡",
    error: "❌",
    start: "🚀",
    skip: "⏭️",
    ruby: "💎",
    new: "✨",
    # Version checker
    fetch: "📥",
    # PR creator
    branch: "🌿",
    commit: "📦",
    push: "🚀",
    pr: "📋",
    close: "🔒"
  }.freeze

  private

  # Log a message with optional color and emoji
  #
  # @param message [String] The message to log
  # @param color [Symbol] Color key from COLORS (default: :reset)
  # @param emoji [Symbol, nil] Emoji key from EMOJI (default: nil)
  def log(message, color = :reset, emoji: nil)
    prefix = emoji ? "#{EMOJI[emoji]} " : ""
    output.puts "#{COLORS[color]}#{prefix}#{message}#{COLORS[:reset]}"
  end
end
