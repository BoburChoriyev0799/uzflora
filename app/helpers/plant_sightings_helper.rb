module PlantSightingsHelper
  def plant_sighting_status_badge(sighting)
    content_tag(:span, I18n.t(sighting.status, scope: 'plant_sightings.status'),
                class: "sighting-status-badge status-#{sighting.status}")
  end

  # Navbar'dagi "Tasdiqlash uchun" tugmasidagi son belgisi uchun —
  # PlantSightingsController#pending bilan bir xil scope.
  def pending_plant_sightings_count
    PlantSighting.published.known.pending.count
  end
end
