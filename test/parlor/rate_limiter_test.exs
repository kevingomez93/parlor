defmodule Parlor.RateLimiterTest do
  use ExUnit.Case, async: false

  alias Parlor.RateLimiter

  setup do
    on_exit(fn -> RateLimiter.reset(:test_key) end)
    :ok
  end

  test "allows requests within the limit" do
    assert RateLimiter.allow?(:test_key, 3, 10_000)
    assert RateLimiter.allow?(:test_key, 3, 10_000)
    assert RateLimiter.allow?(:test_key, 3, 10_000)
  end

  test "denies requests over the limit" do
    assert RateLimiter.allow?(:test_key, 2, 10_000)
    assert RateLimiter.allow?(:test_key, 2, 10_000)
    refute RateLimiter.allow?(:test_key, 2, 10_000)
  end

  test "isolates keys" do
    assert RateLimiter.allow?(:key_a, 1, 10_000)
    refute RateLimiter.allow?(:key_a, 1, 10_000)
    assert RateLimiter.allow?(:key_b, 1, 10_000)
  end

  test "reset clears counters for a key" do
    assert RateLimiter.allow?(:test_key, 1, 10_000)
    refute RateLimiter.allow?(:test_key, 1, 10_000)

    :ok = RateLimiter.reset(:test_key)

    assert RateLimiter.allow?(:test_key, 1, 10_000)
  end
end
