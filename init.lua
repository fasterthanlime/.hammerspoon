-----------------------------------------
-- Paste as Markdown (⌥⌘V)
-----------------------------------------

local hotkey = { "alt", "cmd" } -- modifiers
local key    = "v"              -- key

-- Get HTML (if present) or plain text from the clipboard
local function getClipboardSource()
    local types = hs.pasteboard.contentTypes() or {}
    local htmlUTI = nil

    for _, uti in ipairs(types) do
        if uti == "public.html" or uti == "public.xhtml" then
            htmlUTI = uti
            break
        end
    end

    if htmlUTI then
        -- raw HTML bytes as a Lua string
        local html = hs.pasteboard.readDataForUTI(nil, htmlUTI)
        if html and #html > 0 then
            return html, true
        end
    end

    -- Fallback: plain string contents
    local txt = hs.pasteboard.getContents() or ""
    return txt, false
end

-- Run pandoc by writing to a temp file (avoids shell quoting hell)
local function pandocHtmlToMarkdown(html)
    local tmp = os.tmpname()
    local f = io.open(tmp, "w")
    f:write(html)
    f:close()

    -- Uses whatever pandoc is on PATH (Homebrew one is fine)
    local cmd = "pandoc -f html -t gfm-raw_html " .. tmp
    local md  = hs.execute(cmd, true) -- true = capture output

    os.remove(tmp)

    -- Strip base64 images from markdown output
    -- Pattern matches: ![alt](data:image/...;base64,...)
    md = md:gsub("%b[]%b()", function(img)
        if img:find("data:image") then
            return ""
        end
        return img
    end)

    -- Also strip inline image tags that might be present
    md = md:gsub("<img [^>]*src=['\"][^'\"]*data:image/[^'\"]*['\"][^>]*>", "")

    return md
end

hs.hotkey.bind(hotkey, key, function()
    local original = hs.pasteboard.getContents() or ""

    local source, isHTML = getClipboardSource()

    if not isHTML then
        -- No HTML on clipboard → just do a normal paste
        hs.eventtap.keyStroke({ "cmd" }, "v", 0)
        return
    end

    local ok, md = pcall(pandocHtmlToMarkdown, source)
    if not ok or not md or #md == 0 then
        -- Something went wrong → fall back to normal paste
        hs.eventtap.keyStroke({ "cmd" }, "v", 0)
        return
    end

    -- Put Markdown on clipboard, paste, then restore original
    hs.pasteboard.setContents(md)
    hs.eventtap.keyStroke({ "cmd" }, "v", 0)

    hs.timer.doAfter(0.2, function()
        hs.pasteboard.setContents(original)
    end)
end)

-----------------------------------------
-- Alt-text from clipboard image (⌥⌘A)
-- Verbose debug logging
-----------------------------------------

local OPENAI_API_KEY = hs.settings.get("openai_api_key")
if not OPENAI_API_KEY then
    hs.alert.show("Missing OpenAI API key (hs.settings)")
    print("[ALT-TEXT] ERROR: API key missing in hs.settings")
end

local ALT_HOTKEY_MODS = { "alt", "cmd" }
local ALT_HOTKEY_KEY  = "a"

local function log(...)
    print("[ALT-TEXT]", ...)
end

local function truncate(str, n)
    n = n or 500
    if #str > n then
        return str:sub(1, n) .. "... (truncated)"
    else
        return str
    end
end

local function generateAltTextFromClipboardImage()
    log("Hotkey fired")

    if not OPENAI_API_KEY then
        log("FATAL: No API key set")
        hs.alert.show("OpenAI API key missing")
        return
    end

    local types = hs.pasteboard.contentTypes() or {}
    log("Clipboard UTIs:", hs.inspect(types))

    local img = hs.pasteboard.readImage()
    if not img then
        log("ERROR: No image found on clipboard")
        hs.alert.show("No image on clipboard")
        return
    end

    log("Image found, encoding as data URL…")
    -- encodeAsURLString returns a complete data URL (e.g., "data:image/png;base64,...")
    local dataUrl = img:encodeAsURLString(false, "PNG")
    if not dataUrl then
        log("ERROR: encodeAsURLString returned nil")
        hs.alert.show("Image encoding failed")
        return
    end
    log("Data URL length:", #dataUrl)

    log("Building OpenAI request body…")
    local bodyTable = {
        model = "gpt-4o-mini",
        messages = {
            {
                role = "system",
                content = "Provide descriptive HTML alt text. Respond with only the alt text."
            },
            {
                role = "user",
                content = {
                    { type = "text",      text = "Generate alt text for this image." },
                    { type = "image_url", image_url = { url = dataUrl } }
                }
            }
        },
        max_tokens = 80,
    }

    local bodyJson = hs.json.encode(bodyTable)

    log("Request JSON (truncated):")
    log(truncate(bodyJson, 800))
    log("Sending request to OpenAI…")

    local headers = {
        ["Content-Type"]  = "application/json",
        ["Authorization"] = "Bearer " .. OPENAI_API_KEY,
    }

    hs.http.asyncPost(
        "https://api.openai.com/v1/chat/completions",
        bodyJson,
        headers,
        function(status, respBody, respHeaders)
            log("HTTP status:", status)
            log("Response headers:", hs.inspect(respHeaders))

            if not respBody then
                log("FATAL: No response body from OpenAI")
                hs.alert.show("No response from OpenAI")
                return
            end

            log("Raw JSON response (truncated):")
            log(truncate(respBody, 1500))

            local ok, decoded = pcall(hs.json.decode, respBody)
            if not ok or not decoded then
                log("JSON decode ERROR:", ok, decoded)
                hs.alert.show("Alt text: JSON decode failure")
                return
            end

            if not decoded.choices or not decoded.choices[1] then
                log("Malformed response. No choices.")
                hs.alert.show("Alt text: Bad response")
                return
            end

            local alt = decoded.choices[1].message.content
            log("Final ALT TEXT:", alt)

            hs.pasteboard.setContents(alt)
            hs.alert.show("Alt text generated ✔")
        end
    )
end

hs.hotkey.bind(ALT_HOTKEY_MODS, ALT_HOTKEY_KEY, generateAltTextFromClipboardImage)

log("Alt-text hotkey (⌥⌘A) ready")
