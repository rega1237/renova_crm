import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "prospectingSellerField",
    "assignedSellerField",
    "sourceSelect",
    "statusSelect",
  ];

  connect() {
    this.toggleFields();
  }

  toggleFields() {
    this.toggleProspectingSellerField();
    this.toggleAssignedSellerField();
  }

  toggleProspectingSellerField() {
    const sourceValue = this.sourceSelectTarget.value;
    const requiresProspectingSeller = ["prospectacion", "referencia"].includes(
      sourceValue
    );

    if (requiresProspectingSeller) {
      this.prospectingSellerFieldTarget.classList.remove("hidden");
    } else {
      this.prospectingSellerFieldTarget.classList.add("hidden");
    }
  }

  toggleAssignedSellerField() {
    const statusValue = this.statusSelectTarget.value;
    const statusesRequiringAssignment = [
      "cita_agendada",
      "reprogramar",
      "vendido",
      "mal_credito",
      "no_cerro",
    ];

    if (statusesRequiringAssignment.includes(statusValue)) {
      this.assignedSellerFieldTarget.classList.remove("hidden");
    } else {
      this.assignedSellerFieldTarget.classList.add("hidden");
    }
  }

  sourceChanged() {
    this.toggleProspectingSellerField();
  }

  statusChanged() {
    this.toggleAssignedSellerField();
  }
}
