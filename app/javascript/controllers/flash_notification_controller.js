import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    // Inicia la animación de entrada
    requestAnimationFrame(() => {
      this.element.classList.remove("opacity-0", "translate-x-full");
    });

    // Inicia el temporizador para desaparecer
    this.startTimeout();
  }

  startTimeout() {
    this.timeout = setTimeout(() => {
      this.close();
    }, 4000); // 4 segundos
  }

  close() {
    // Detiene cualquier temporizador existente para evitar cierres múltiples
    clearTimeout(this.timeout);

    // Inicia la animación de salida
    this.element.classList.add("opacity-0");

    // Espera a que termine la transición para eliminar el elemento del DOM
    this.element.addEventListener(
      "transitionend",
      () => {
        this.element.remove();
      },
      { once: true }
    );
  }
}
