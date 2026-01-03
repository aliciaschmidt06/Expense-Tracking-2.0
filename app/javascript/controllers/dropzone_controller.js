// app/javascript/controllers/dropzone_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "area", "filename", "configInput", "configArea", "configFilename"]

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
      this.filenameTarget.textContent = `Selected file: ${this.inputTarget.files[0].name}`
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
}
