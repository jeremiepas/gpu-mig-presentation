---
marp: true
theme: wescale-teal
title: GPU MIG vs Time Slicing
author: WeScale
---

<!--
  ╔══════════════════════════════════════════════════════════════╗
  ║              WeScale Teal Theme - GPU MIG Presentation       ║
  ╚══════════════════════════════════════════════════════════════╝
-->

<style>
/* ══════════════════════════════════════════════════════════════════
   WeScale Teal Theme - GPU MIG vs Time Slicing
   ══════════════════════════════════════════════════════════════════ */

@import url('https://fonts.googleapis.com/css2?family=Montserrat:wght@300;400;600;700&family=Fira+Code:wght@400;500&display=swap');

:root {
  --wsc-gradient-start: #2C9DA0;
  --wsc-gradient-end: #1A5E7A;
  --wsc-white: #FFFFFF;
  --wsc-dark-blue: #1A5E7A;
  --wsc-text-dark: #1A5E7A;
  --wsc-text-light: #E0E0E0;
  --wsc-text-muted: #666666;
  --wsc-accent: #4ECDC4;
  --wsc-accent-light: rgba(78, 205, 196, 0.3);
  --wsc-divider: #CCCCCC;
  
  --wsc-font: 'Montserrat', 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
  --wsc-code-font: 'Fira Code', 'Consolas', monospace;
  --wsc-title-size: 60pt;
  --wsc-section-num-size: 72pt;
  --wsc-page-title-size: 48pt;
  --wsc-subtitle-size: 22pt;
  --wsc-body-size: 18pt;
  --wsc-margin: 80px;
  --wsc-margin-top: 60px;
}

section {
  font-family: var(--wsc-font);
  color: var(--wsc-dark-blue);
  background: var(--wsc-white);
  padding: var(--wsc-margin-top) var(--wsc-margin) var(--wsc-margin-bottom);
  line-height: 1.6;
  font-size: var(--wsc-body-size);
}

/* Title Slide */
section.title-slide {
  background: linear-gradient(to right, var(--wsc-gradient-start) 0%, var(--wsc-gradient-end) 100%);
  color: var(--wsc-white);
}

section.title-slide::after {
  content: '';
  position: absolute;
  right: -150px;
  top: 50%;
  transform: translateY(-50%);
  width: 600px;
  height: 600px;
  border: 2px solid var(--wsc-accent);
  border-radius: 50%;
  opacity: 0.8;
}

section.title-slide h1 {
  color: var(--wsc-white);
  font-size: var(--wsc-title-size);
  font-weight: 700;
  margin-top: 100px;
}

section.title-slide h2 {
  color: var(--wsc-white);
  font-size: var(--wsc-subtitle-size);
  font-weight: 400;
}

/* Section Header */
.section-header {
  font-size: 18pt;
  color: var(--wsc-accent);
  font-weight: 700;
  margin-bottom: 10px;
}

.section-header .number {
  font-size: 36pt;
  vertical-align: middle;
}

.section-header .title {
  font-size: 28pt;
  font-weight: 400;
  color: var(--wsc-dark-blue);
  vertical-align: middle;
}

/* Content Slide Headers */
section h1 {
  font-size: var(--wsc-page-title-size);
  font-weight: 700;
  color: var(--wsc-dark-blue);
  margin-top: 30px;
  margin-bottom: 40px;
}

section h2 {
  font-size: var(--wsc-subtitle-size);
  font-weight: 600;
  color: var(--wsc-dark-blue);
  margin-top: 20px;
  margin-bottom: 20px;
}

section h3 {
  font-size: 20pt;
  font-weight: 600;
  color: var(--wsc-accent);
  margin-top: 15px;
  margin-bottom: 10px;
}

/* Lists */
ul {
  list-style-type: disc;
  padding-left: 30px;
}

ul li {
  margin: 12px 0;
  line-height: 1.5;
}

ul li::marker {
  color: var(--wsc-accent);
}

ul.arrow-list {
  list-style: none;
  padding-left: 0;
}

ul.arrow-list > li {
  position: relative;
  padding-left: 35px;
  margin: 18px 0;
}

ul.arrow-list > li::before {
  content: '→';
  position: absolute;
  left: 0;
  color: var(--wsc-accent);
  font-weight: bold;
}

/* Code */
code {
  font-family: var(--wsc-code-font);
  font-size: 0.9em;
  background: var(--wsc-accent-light);
  color: var(--wsc-dark-blue);
  padding: 2px 8px;
  border-radius: 4px;
}

pre {
  background: rgba(26, 94, 122, 0.1);
  border-radius: 8px;
  padding: 20px;
  margin: 20px 0;
  border-left: 4px solid var(--wsc-accent);
  overflow-x: auto;
}

pre code {
  background: transparent;
  padding: 0;
  font-size: 14pt;
  line-height: 1.5;
  font-family: var(--wsc-code-font);
}

/* Tables */
table {
  width: 100%;
  border-collapse: collapse;
  margin: 20px 0;
  font-size: 16pt;
}

th {
  background: rgba(78, 205, 196, 0.15);
  color: var(--wsc-dark-blue);
  font-weight: 600;
  padding: 15px;
  text-align: left;
}

td {
  padding: 12px 15px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

tr:hover td {
  background: rgba(78, 205, 196, 0.05);
}

/* Two Columns */
.two-columns {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 50px;
}

/* Accent Box */
.accent-box {
  background: var(--wsc-accent-light);
  border-left: 4px solid var(--wsc-accent);
  padding: 20px 25px;
  margin: 25px 0;
  border-radius: 0 8px 8px 0;
}

/* Footer */
footer {
  position: absolute;
  bottom: 30px;
  right: 80px;
  font-size: 12pt;
  color: var(--wsc-text-muted);
}

section.title-slide footer {
  color: var(--wsc-white);
  opacity: 0.6;
}

/* Highlight */
strong {
  color: var(--wsc-dark-blue);
  font-weight: 600;
}

em {
  font-style: italic;
  color: var(--wsc-dark-blue);
}

/* Warning/Success boxes */
.warning-box {
  background: #fee;
  border-left: 4px solid #f85149;
  padding: 15px 20px;
  margin: 15px 0;
  border-radius: 0 8px 8px 0;
}

.success-box {
  background: #efe;
  border-left: 4px solid #7ee787;
  padding: 15px 20px;
  margin: 15px 0;
  border-radius: 0 8px 8px 0;
}
</style>

---

<!-- SLIDE 1: Title -->

<section class="title-slide">

<p class="wescale-logo">we scale</p>
<p class="wescale-meta">GPU Optimization</p>

# GPU MIG vs Time Slicing

## Optimisation GPU dans Kubernetes

</section>

---

<!-- SLIDE 2: Context -->

<p class="wescale-logo" style="font-size: 16pt; color: #1A5E7A;">Contexte</p>

# Le problème

<ul class="arrow-list">
  <li><strong>Coût GPU en forte hausse</strong> — AWS, GCP, Scaleway</li>
  <li>Multiples workloads sur un même node</li>
  <li>Besoin d'isolation vs资源共享</li>
</ul>

<div class="accent-box">
  <strong>Question:</strong> Comment optimiser l'utilisation sans impacter les performances?
</div>

<footer>GPU MIG vs Time Slicing</footer>

---

<!-- SLIDE 3: Solutions -->

<p class="wescale-logo" style="font-size: 16pt; color: #1A5E7A;">Solutions</p>

# Techniques de partage GPU

| Technique | Isolation | Complexité | GPUs supportés |
|-----------|-----------|------------|---------------|
| **Time Slicing** | Logicielle | Simple | Tous |
| **vGPU Software** | Partielle | Moyenne | NVIDIA vGPU |
| **MIG** | Physique | Élevée | A100, A30, H100 |

<footer>GPU MIG vs Time Slicing</footer>

---

<!-- SLIDE 4: Time Slicing -->

<p class="wescale-logo" style="font-size: 16pt; color: #1A5E7A;">Time Slicing</p>

# Partage temporel du GPU

```yaml
sharing:
  timeSlicing:
    resources:
      - name: nvidia.com/gpu
        replicas: 4
```

<ul class="arrow-list">
  <li>Configuration simple</li>
  <li>Fonctionne sur tous les GPUs</li>
  <li class="warning-box">⚠️ Pas d'isolation mémoire</li>
  <li class="warning-box">⚠️ Contention en cas de forte charge</li>
</ul>

<footer>GPU MIG vs Time Slicing</footer>

---

<!-- SLIDE 5: MIG -->

<p class="wescale-logo" style="font-size: 16pt; color: #1A5E7A;">MIG</p>

# Multi-Instance GPU

```
nvidia-smi -L
GPU 0: NVIDIA A100-SXM4-40GB
  MIG 1g.5gb      Devices 1: 19
  MIG 2g.10gb     Devices 1: 9
  MIG 3g.20gb     Devices 1: 5
  MIG 7g.40gb     Devices 1: 1
```

<ul class="arrow-list">
  <li>Isolation <strong>physique</strong> du GPU</li>
  <li>Garantie de ressources</li>
  <li class="success-box">✅ Performance déterministe</li>
  <li class="warning-box">⚠️ Requiert GPU supporté (A100, A30, H100)</li>
</ul>

<footer>GPU MIG vs Time Slicing</footer>

---

<!-- SLIDE 6: Comparison -->

<p class="wescale-logo" style="font-size: 16pt; color: #1A5E7A;">Comparaison</p>

# Time Slicing vs MIG

| Critère | Time Slicing | MIG |
|---------|--------------|-----|
| Isolation | ❌ Aucune | ✅ Physique |
| Impact crash | Cascade | Isolated |
| Latence | Variable | Déterministe |
| Utilisation | ~60% | ~95% |
| Setup | Simple | Complexe |

<footer>GPU MIG vs Time Slicing</footer>

---

<!-- SLIDE 7: Demo Time Slicing -->

<p class="wescale-logo" style="font-size: 16pt; color: #1A5E7A;">Démo</p>

# Time Slicing en pratique

```bash
# Lancer les pods
kubectl apply -f 06-moshi-timeslicing.yaml
kubectl get pods -n moshi-demo
```

<div class="accent-box">
  <strong>Observation:</strong>
</div>

<ul>
  <li>Contention mémoire entre pods</li>
  <li>Crash d'un pod → impacte les autres</li>
  <li>Latence variable</li>
</ul>

<footer>GPU MIG vs Time Slicing - Live Demo</footer>

---

<!-- SLIDE 8: Demo MIG -->

<p class="wescale-logo" style="font-size: 16pt; color: #1A5E7A;">Démo</p>

# MIG en pratique

```bash
# Activer MIG
kubectl apply -f 07-moshi-mig.yaml

# Vérifier instances
nvidia-smi -L
```

<div class="accent-box">
  <strong>Observation:</strong>
</div>

<ul>
  <li>Chaque pod sur instance MIG dédiée</li>
  <li>Crash contenu à une instance</li>
  <li>Performance garantie</li>
</ul>

<footer>GPU MIG vs Time Slicing - Live Demo</footer>

---

<!-- SLIDE 9: Grafana -->

<p class="wescale-logo" style="font-size: 16pt; color: #1A5E7A;">Métriques</p>

# Grafana Dashboard

<div class="two-columns">
  <div>
    <h3>Avant MIG</h3>
    <ul>
      <li>Utilisation ~60%</li>
      <li>OOM cascade</li>
      <li>Latence variable</li>
    </ul>
  </div>
  <div>
    <h3>Après MIG</h3>
    <ul>
      <li>Utilisation ~95%</li>
      <li>Crash isolée</li>
      <li>Latence stable</li>
    </ul>
  </div>
</div>

<p style="font-size: 14pt; color: #666;">Dashboard: <code>k8s/04-grafana.yaml</code></p>

<footer>GPU MIG vs Time Slicing</footer>

---

<!-- SLIDE 10: Use Cases -->

<p class="wescale-logo" style="font-size: 16pt; color: #1A5E7A;">Roadmap</p>

# Use Cases / POC

<ul class="arrow-list">
  <li><strong>POC 1:</strong> Time Slicing sur dev cluster
    <ul>
      <li>Workloads petits / non critiques</li>
      <li>Mesurer overhead de contention</li>
    </ul>
  </li>
  <li><strong>POC 2:</strong> MIG sur production A100
    <li>Workloads critiques</li>
    <li>Mesurer isolation</li>
  </li>
  <li><strong>POC 3:</strong> Approche hybride
    <ul>
      <li>MIG pour prod + Time Slicing pour dev</li>
    </ul>
  </li>
</ul>

<footer>GPU MIG vs Time Slicing</footer>

---

<!-- SLIDE 11: Setup -->

<p class="wescale-logo" style="font-size: 16pt; color: #1A5E7A;">Setup</p>

# Infrastructure (30min)

<div class="two-columns">
  <div>
    <h3>Déploiement</h3>
    <ol>
      <li>Terraform → Scaleway L4 GPU</li>
      <li>K3s + NVIDIA Operator</li>
      <li>MIG configuration</li>
      <li>Grafana + Prometheus</li>
    </ol>
  </div>
  <div>
    <h3>Commandes</h3>
    <pre><code># Deploy
gh workflow run deploy.yml

# Destroy
gh workflow run destroy.yml</code></pre>
  </div>
</div>

<footer>GPU MIG vs Time Slicing</footer>

---

<!-- SLIDE 12: Takeaways -->

<p class="wescale-logo" style="font-size: 16pt; color: #1A5E7A;">Conclusion</p>

# Takeaways

<ul class="arrow-list">
  <li><strong>Time Slicing:</strong> Solution simple, isolation limitée</li>
  <li><strong>MIG:</strong> Isolation physique, performances garanties</li>
  <li>Choisir selon criticité des workloads</li>
  <li>Démonstration live = la preuve par l'action</li>
</ul>

<div class="accent-box">
  <strong>Repository:</strong> github.com/jeremiepas/gpu-mig-presentation
</div>

<footer>GPU MIG vs Time Slicing</footer>

---

<!-- SLIDE 13: Questions -->

<section class="title-slide">

<p class="wescale-logo">we scale</p>
<p class="wescale-meta">Q&A</p>

# Questions ?

## Merci !

</section>

