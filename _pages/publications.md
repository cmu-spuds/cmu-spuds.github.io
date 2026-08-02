---
layout: page
permalink: /publications/
title: publications
description:
nav: true
nav_order: 4
---

{% assign lab_members = "" | split: "" %}
{% for member in site.data.people.advisor %}
{% assign lab_members = lab_members | push: member.name %}
{% endfor %}
{% for member in site.data.people.students %}
{% assign lab_members = lab_members | push: member.name %}
{% endfor %}
{% for member in site.data.people.alumni %}
{% assign lab_members = lab_members | push: member.name %}
{% endfor %}

<!-- Search bar -->
<div class="search-container">
  <input type="text" id="publicationSearch" onkeyup="filterPublications()" placeholder="Search for publications...">
</div>

<!-- publications.html -->
<div class="publications">
  {% assign publications = site.data.publications | sort: "year" | reverse %}
  {% assign grouped_publications = publications | group_by: "year" %}
  
  {% for year in grouped_publications %}
    <h2 class="publication-year">{{year.name}}</h2>
    {% for publication in year.items %}
      <div class="publication">
        <div class="publication-title">
          {{ publication.title }}
        </div>
        <div class="publication-authors">
          {% for author in publication.authors %}
            {% if lab_members contains author.name %}
              <strong class="lab-member"><a href="#" onclick="setSearch('{{ author.name }}'); return false;">{{ author.name }}</a></strong>{% unless forloop.last %},{% endunless %}
            {% elsif author.self %}
              <strong><a href="#" onclick="setSearch('{{ author.name }}'); return false;">{{ author.name }}</a></strong>{% unless forloop.last %},{% endunless %}
            {% else %}
              <a href="#" onclick="setSearch('{{ author.name }}'); return false;">{{ author.name }}</a>{% unless forloop.last %},{% endunless %}
            {% endif %}
          {% endfor %}
        </div>
        <div class="publication-venue">
          <a href="#" onclick="setSearch('{{ publication.venue }}'); return false;">{{ publication.venue }}</a>
        </div>
        {% if publication.awards.size > 0 %}
          <div class="publication-awards">
            {% for award in publication.awards %}
              <span class="award"> 🏆 {{ award.body }} ({{ award.year }})</span>
            {% endfor %}
          </div>
        {% endif %}
        {% if publication.tags %}
          <div class="publication-tags">
            {% assign tags = publication.tags | split: ";" %}
            {% for tag in tags %}
              <span class="tag"><a href="#" onclick="setSearch('{{ tag }}'); return false;">{{ tag }}</a></span>
            {% endfor %}
          </div>
        {% endif %}
        {% include publication_actions.liquid publication=publication %}
      </div>
    {% endfor %}
  {% endfor %}
</div>

<script>
function filterPublications() {
  var input, filter, publications, publication, i, txtValue;
  input = document.getElementById('publicationSearch');
  filter = input.value.toUpperCase();
  publications = document.getElementsByClassName('publication');

  for (i = 0; i < publications.length; i++) {
    publication = publications[i];
    txtValue = publication.textContent || publication.innerText;
    if (txtValue.toUpperCase().indexOf(filter) > -1) {
      publication.style.display = "";
    } else {
      publication.style.display = "none";
    }
  }

  // Hide/show year headers
  var years = document.getElementsByClassName('publication-year');
  for (i = 0; i < years.length; i++) {
    var year = years[i];
    var nextElement = year.nextElementSibling;
    var visiblePublications = false;
    while (nextElement && !nextElement.classList.contains('publication-year')) {
      if (nextElement.classList.contains('publication') && nextElement.style.display !== "none") {
        visiblePublications = true;
        break;
      }
      nextElement = nextElement.nextElementSibling;
    }
    year.style.display = visiblePublications ? "" : "none";
  }
}

function setSearch(term) {
  var searchInput = document.getElementById('publicationSearch');
  searchInput.value = term;
  filterPublications();
}
</script>

<script src="{{ '/assets/js/spuds-home.js' | relative_url }}" defer></script>
