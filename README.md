# my spoons! oh, my spoons!

I just recently discovered Hammerspoon, and that it could solve:

  * No matter what's in my clipboard, paste it as Markdown. 
  * Use a vision model to generate alt text for the image in my clipboard.

I'm sure other ideas will come up and I'm gonna collect them here. Have fun!

## Setup

Install Hammerspoon itself:

```bash
brew install --cask hammerspoon
```

Launch it once, go through the setting, enable launch it, log in, but most
importantly, give it accessibility permissions and restart it. 

## Pandoc

Used to convert HTML to Markdown:

```bash
brew install pandoc
```

Note: pandoc is a beast. It's going to be slow the first time and slightly less
slow the other times. But it's also very good. 

## OpenAI key

For the alt text functionality you have to give it an OpenAI key in the
Hammerspoon console, like so:

```lua
hs.settings.set("openai_api_key", "sk-your-key-here")
```

Because I'm fairly sure this is not encrypted, you might want to use a key that
has a spending limit on it.

Using OpenAI costs money. Be careful with your money.
