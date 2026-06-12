import folium

# Titik tengah kamera (Lembah Mina)
peta_haji = folium.Map(location=[21.415, 39.885], zoom_start=12, tiles='OpenStreetMap')

# ZONA A: Makkah (Biru)
folium.Rectangle(
    bounds=[[21.380, 39.764], [21.460, 39.850]],
    color='#3186cc',
    fill=True,
    fill_opacity=0.3,
    popup='<b>ZONA A: Makkah</b><br>Pusat Kota & Haram',
    tooltip='ZONA A'
).add_to(peta_haji)

# ZONA B: Mina (Hijau) - Area Krusial Sprint 2
folium.Rectangle(
    bounds=[[21.390, 39.850], [21.440, 39.920]],
    color='#28a745',
    fill=True,
    fill_opacity=0.4,
    popup='<b>ZONA B: Mina</b><br>Lembah Tenda & Jamarat',
    tooltip='ZONA B (Fokus Sprint 2)'
).add_to(peta_haji)

# ZONA C: Arafah (Merah)
folium.Rectangle(
    bounds=[[21.311, 39.920], [21.400, 40.018]],
    color='#dc3545',
    fill=True,
    fill_opacity=0.3,
    popup='<b>ZONA C: Arafah</b><br>Muzdalifah & Jabal Wukuf',
    tooltip='ZONA C'
).add_to(peta_haji)

# Eksekusi dan simpan sebagai file HTML
peta_haji.save('Visualisasi_Spasial_Roblox.html')
print("✅ Peta berhasil dibuat! Silakan buka file 'Visualisasi_Spasial_Roblox.html' di browser.")