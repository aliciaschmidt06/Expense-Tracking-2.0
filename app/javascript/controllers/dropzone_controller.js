// app/javascript/controllers/dropzone_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "area", "filename", "configInput", "configArea", "configFilename", "account", "error"]

  connect() {
    // CSV area may not exist
    if (this.hasAreaTarget && this.hasInputTarget) {
      this.areaTarget.addEventListener("click", () => this.inputTarget.click())
      this.areaTarget.addEventListener("dragover", (e) => this.onDragOver(e))
      this.areaTarget.addEventListener("dragleave", (e) => this.onDragLeave(e))
      this.areaTarget.addEventListener("drop", (e) => this.onDrop(e, "input"))
    }

    // YAML area
    if (this.hasConfigAreaTarget && this.hasConfigInputTarget) {
      this.configAreaTarget.addEventListener("click", () => this.configInputTarget.click())
      this.configAreaTarget.addEventListener("dragover", (e) => this.onDragOver(e))
      this.configAreaTarget.addEventListener("dragleave", (e) => this.onDragLeave(e))
      this.configAreaTarget.addEventListener("drop", (e) => this.onDrop(e, "configInput"))
    }
  }

  onDragOver(event) {
    event.preventDefault()
    event.currentTarget.classList.add("bg-gray-100")
  }

  onDragLeave(event) {
    event.preventDefault()
    event.currentTarget.classList.remove("bg-gray-100")
  }

  onDrop(event, inputTargetName) {
    event.preventDefault()
    event.currentTarget.classList.remove("bg-gray-100")

    const files = event.dataTransfer.files
    if (files.length > 0) {
      const inputTarget = this[inputTargetName + "Target"]
      inputTarget.files = files

      if (inputTargetName === "input") {
        this.updateFilename()
      } else if (inputTargetName === "configInput") {
        this.updateConfigFilename()
      }
    }
  }

  fileSelected() { this.updateFilename() }
  configSelected() { this.updateConfigFilename() }

  updateFilename() {
    if (this.inputTarget.files.length > 0) {
      const fname = this.inputTarget.files[0].name
      this.filenameTarget.textContent = `Selected file: ${fname}`
      // Auto-populate account name from filename (strip extension) if the field is empty
      try {
        if (this.hasAccountTarget) {
          const base = fname.replace(/\.[^/.]+$/, '') // remove extension
          if (!this.accountTarget.value || this.accountTarget.value.trim() === '') {
            // replace underscores/dashes with spaces and trim
            this.accountTarget.value = base.replace(/[_\-]+/g, ' ').trim()
          }
        }
      } catch (e) {
        // non-fatal
      }
    } else {
      this.filenameTarget.textContent = ""
    }
  }

  updateConfigFilename() {
    if (this.configInputTarget.files.length > 0) {
      this.configFilenameTarget.textContent = `Selected file: ${this.configInputTarget.files[0].name}`
    } else {
      this.configFilenameTarget.textContent = ""
    }
  }

  // Validate before submitting the form: if an account name is provided but no CSV file selected,
  validateBeforeSubmit(event) {
    try {
      console.debug && console.debug('[dropzone] validateBeforeSubmit called')
      const hasAccount = this.hasAccountTarget && this.accountTarget.value && this.accountTarget.value.trim() !== ''
      const hasFile = this.hasInputTarget && this.inputTarget.files && this.inputTarget.files.length > 0

      if (hasAccount && !hasFile) {
        console.debug && console.debug('[dropzone] validation failed: account present but no file')
        event.preventDefault()
        if (this.hasErrorTarget) {
          this.errorTarget.textContent = 'Please upload a CSV file.'
          this.errorTarget.classList.remove('hidden')
        } else {
          alert('Please upload a CSV file.')
        }

        if (this.hasAreaTarget) {
          this.areaTarget.classList.add('ring-2', 'ring-red-300')
        }

        setTimeout(() => {
          if (this.hasErrorTarget) {
            this.errorTarget.classList.add('hidden')
            this.errorTarget.textContent = ''
          }
          if (this.hasAreaTarget) {
            this.areaTarget.classList.remove('ring-2', 'ring-red-300')
          }
        }, 5000)
      }
      else {
        console.debug && console.debug('[dropzone] validation passed, allowing submit, showing loading state')
        // Allowing submit: show a simple loading state on the submit button to give feedback
        try {
          const form = event.target || this.element
          const submit = form.querySelector('input[type="submit"], button[type="submit"]')
          if (submit) {
            submit.dataset.origText = submit.innerHTML || submit.value || ''
            if (submit.tagName.toLowerCase() === 'input') {
              submit.value = 'Importing...'
            } else {
              submit.innerHTML = 'Importing...'
            }
            submit.disabled = true
            // optional: add an aria-busy flag
            submit.setAttribute('aria-busy', 'true')
          }
        } catch (e) {
          // non-fatal
        }
        // add a small timeout to re-enable the button if submission was blocked by something else
        setTimeout(() => {
          try {
            const form = event.target || this.element
            const submit = form.querySelector('input[type="submit"], button[type="submit"]')
            if (submit && submit.disabled) {
              // if still disabled after 5s, enable so user isn't stuck
              submit.disabled = false
              if (submit.tagName.toLowerCase() === 'input') {
                submit.value = submit.dataset.origText || 'Import'
              } else {
                submit.innerHTML = submit.dataset.origText || 'Import'
              }
              submit.removeAttribute('aria-busy')
            }
          } catch (e) {}
        }, 5000)
      }
    } catch (e) {
      return true
    }
  }
}
