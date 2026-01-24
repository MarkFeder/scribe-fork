let Hooks = {}

Hooks.Clipboard = {
    mounted() {
        this.handleEvent("copy-to-clipboard", ({ text: text }) => {
            navigator.clipboard.writeText(text).then(() => {
                this.pushEventTo(this.el, "copied-to-clipboard", { text: text })
                setTimeout(() => {
                    this.pushEventTo(this.el, "reset-copied", {})
                }, 2000)
            })
        })
    }
}

Hooks.ScrollToBottom = {
    mounted() {
        this.scrollToBottom()
    },
    updated() {
        this.scrollToBottom()
    },
    scrollToBottom() {
        this.el.scrollTop = this.el.scrollHeight
    }
}

Hooks.TextareaAutoResize = {
    mounted() {
        this.resize()
        this.el.addEventListener("input", () => this.resize())
    },
    updated() {
        this.resize()
    },
    resize() {
        this.el.style.height = "auto"
        this.el.style.height = Math.min(this.el.scrollHeight, 120) + "px"
    }
}

export default Hooks