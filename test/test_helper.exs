ExUnit.start()

# Configure test environment
Application.put_env(:spex, :adapter, Spex.Adapters.Default)
Application.put_env(:spex, :screenshot_dir, "test/tmp")

# Ensure test directories exist
File.mkdir_p!("test/tmp")