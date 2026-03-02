class SkillsCatalog {
  static List<String> forCategory({
    required String lang,
    required String category,
  }) {
    final normalizedLang = lang.toUpperCase();
    switch (category) {
      case 'language':
        return normalizedLang == 'RO' ? _languagesRo : _languagesEn;
      case 'soft':
        return normalizedLang == 'RO' ? _softSkillsRo : _softSkillsEn;
      case 'hard':
        return normalizedLang == 'RO' ? _hardSkillsRo : _hardSkillsEn;
      default:
        return const <String>[];
    }
  }

  static const List<String> _languagesEn = [
    'Abkhaz', 'Afar', 'Afrikaans', 'Akan', 'Albanian', 'Amharic', 'Arabic',
    'Aragonese', 'Armenian', 'Assamese', 'Avaric', 'Avestan', 'Aymara',
    'Azerbaijani', 'Bambara', 'Bashkir', 'Basque', 'Belarusian', 'Bengali',
    'Bihari', 'Bislama', 'Bosnian', 'Breton', 'Bulgarian', 'Burmese',
    'Catalan', 'Chamorro', 'Chechen', 'Chichewa', 'Chinese', 'Chuvash',
    'Cornish', 'Corsican', 'Cree', 'Croatian', 'Czech', 'Danish', 'Divehi',
    'Dutch', 'Dzongkha', 'English', 'Esperanto', 'Estonian', 'Ewe',
    'Faroese', 'Fijian', 'Finnish', 'French', 'Fula', 'Galician', 'Georgian',
    'German', 'Greek', 'Guaraní', 'Gujarati', 'Haitian Creole', 'Hausa',
    'Hebrew', 'Herero', 'Hindi', 'Hiri Motu', 'Hungarian', 'Interlingua',
    'Indonesian', 'Interlingue', 'Irish', 'Igbo', 'Inupiaq', 'Ido',
    'Icelandic', 'Italian', 'Inuktitut', 'Japanese', 'Javanese', 'Kalaallisut',
    'Kannada', 'Kanuri', 'Kashmiri', 'Kazakh', 'Khmer', 'Kikuyu', 'Kinyarwanda',
    'Kirghiz', 'Komi', 'Kongo', 'Korean', 'Kurdish', 'Kuanyama', 'Latin',
    'Luxembourgish', 'Ganda', 'Limburgish', 'Lingala', 'Lao', 'Lithuanian',
    'Luba-Katanga', 'Latvian', 'Manx', 'Macedonian', 'Malagasy', 'Malay',
    'Malayalam', 'Maltese', 'Māori', 'Marathi', 'Marshallese', 'Mongolian',
    'Nauru', 'Navajo', 'Northern Ndebele', 'Nepali', 'Ndonga', 'Norwegian Bokmål',
    'Norwegian Nynorsk', 'Norwegian', 'Sichuan Yi', 'Southern Ndebele',
    'Occitan', 'Ojibwa', 'Church Slavonic', 'Oromo', 'Oriya', 'Ossetian',
    'Panjabi', 'Pāli', 'Persian', 'Polish', 'Pashto', 'Portuguese',
    'Quechua', 'Romansh', 'Kirundi', 'Romanian', 'Russian', 'Sanskrit',
    'Sardinian', 'Sindhi', 'Northern Sami', 'Samoan', 'Sango', 'Serbian',
    'Scottish Gaelic', 'Shona', 'Sinhala', 'Slovak', 'Slovenian', 'Somali',
    'Southern Sotho', 'Spanish', 'Sundanese', 'Swahili', 'Swati', 'Swedish',
    'Tamil', 'Telugu', 'Tajik', 'Thai', 'Tigrinya', 'Tibetan', 'Turkmen',
    'Tagalog', 'Tswana', 'Tonga', 'Turkish', 'Tsonga', 'Tatar', 'Twi',
    'Tahitian', 'Uighur', 'Ukrainian', 'Urdu', 'Uzbek', 'Venda', 'Vietnamese',
    'Volapük', 'Walloon', 'Welsh', 'Wolof', 'Western Frisian', 'Xhosa',
    'Yiddish', 'Yoruba', 'Zhuang', 'Zulu',
  ];

  static const List<String> _languagesRo = [
    'Abhază', 'Afar', 'Afrikaans', 'Akan', 'Albaneză', 'Amharică', 'Arabă',
    'Aragoneză', 'Armeană', 'Assameză', 'Avară', 'Avestică', 'Aymara',
    'Azeră', 'Bambara', 'Bașchiră', 'Bască', 'Belarusă', 'Bengaleză',
    'Bihari', 'Bislama', 'Bosniacă', 'Bretonă', 'Bulgară', 'Birmană',
    'Catalană', 'Chamorro', 'Cecenă', 'Chichewa', 'Chineză', 'Ciuvashă',
    'Cornică', 'Corsicană', 'Cree', 'Croată', 'Cehă', 'Daneză', 'Divehi',
    'Neerlandeză', 'Dzongkha', 'Engleză', 'Esperanto', 'Estonă', 'Ewe',
    'Feroeză', 'Fijiană', 'Finlandeză', 'Franceză', 'Fula', 'Galiciană',
    'Georgiană', 'Germană', 'Greacă', 'Guarani', 'Gujarati', 'Creolă haitiană',
    'Hausa', 'Ebraică', 'Herero', 'Hindi', 'Hiri Motu', 'Maghiară',
    'Interlingua', 'Indoneziană', 'Interlingue', 'Irlandeză', 'Igbo',
    'Inupiaq', 'Ido', 'Islandeză', 'Italiană', 'Inuktitut', 'Japoneză',
    'Javaneză', 'Kalaallisut', 'Kannada', 'Kanuri', 'Kașmiră', 'Kazahă',
    'Khmeră', 'Kikuyu', 'Kinyarwanda', 'Kârgâză', 'Komi', 'Kongo', 'Coreeană',
    'Kurdă', 'Kuanyama', 'Latină', 'Luxemburgheză', 'Ganda', 'Limburgheză',
    'Lingala', 'Lao', 'Lituaniană', 'Luba-Katanga', 'Letonă', 'Manx',
    'Macedoneană', 'Malgașă', 'Malaeză', 'Malayalam', 'Malteză', 'Maori',
    'Marathi', 'Marshallese', 'Mongolă', 'Nauru', 'Navajo',
    'Ndebele de Nord', 'Nepaleză', 'Ndonga', 'Norvegiană Bokmål',
    'Norvegiană Nynorsk', 'Norvegiană', 'Yi Sichuan', 'Ndebele de Sud',
    'Occitană', 'Ojibwa', 'Slavonă bisericească', 'Oromo', 'Oriya', 'Ossetă',
    'Punjabi', 'Pali', 'Persană', 'Poloneză', 'Pașto', 'Portugheză',
    'Quechua', 'Romanșă', 'Kirundi', 'Română', 'Rusă', 'Sanskrită',
    'Sardă', 'Sindhi', 'Sami de Nord', 'Samoană', 'Sango', 'Sârbă',
    'Gaelică scoțiană', 'Shona', 'Singhaleză', 'Slovacă', 'Slovenă',
    'Somaleză', 'Sotho de Sud', 'Spaniolă', 'Sundaneză', 'Swahili', 'Swati',
    'Suedeză', 'Tamilă', 'Telugu', 'Tadjică', 'Thailandeză', 'Tigrinya',
    'Tibetană', 'Turkmenă', 'Tagalog', 'Tswana', 'Tonga', 'Turcă', 'Tsonga',
    'Tătară', 'Twi', 'Tahitiană', 'Uigură', 'Ucraineană', 'Urdu', 'Uzbecă',
    'Venda', 'Vietnameză', 'Volapük', 'Valonă', 'Galeză', 'Wolof',
    'Frizonă de Vest', 'Xhosa', 'Idiș', 'Yoruba', 'Zhuang', 'Zulu',
  ];

  static const List<String> _softSkillsEn = [
    'Accountability', 'Active listening', 'Adaptability', 'Analytical thinking',
    'Assertiveness', 'Attention to detail', 'Business acumen', 'Coaching',
    'Collaboration', 'Communication', 'Conflict resolution', 'Creativity',
    'Critical thinking', 'Cross-functional collaboration', 'Cultural awareness',
    'Customer focus', 'Decision making', 'Delegation', 'Discipline',
    'Emotional intelligence', 'Empathy', 'Facilitation', 'Feedback delivery',
    'Flexibility', 'Growth mindset', 'Influencing', 'Initiative',
    'Innovation mindset', 'Interpersonal skills', 'Leadership', 'Learning agility',
    'Mentoring', 'Negotiation', 'Networking', 'Organization', 'Ownership',
    'Patience', 'People management', 'Persuasion', 'Planning',
    'Presentation skills', 'Prioritization', 'Problem solving',
    'Process thinking', 'Proactivity', 'Professionalism', 'Public speaking',
    'Relationship building', 'Reliability', 'Resilience', 'Responsibility',
    'Risk awareness', 'Self-awareness', 'Self-motivation', 'Stakeholder management',
    'Strategic thinking', 'Stress management', 'Teamwork', 'Time management',
    'Transparency', 'Troubleshooting', 'Verbal communication',
    'Written communication',
  ];

  static const List<String> _softSkillsRo = [
    'Abilități analitice', 'Abilități de prezentare', 'Abilități interpersonale',
    'Adaptabilitate', 'Asertivitate', 'Ascultare activă', 'Atenție la detalii',
    'Autodisciplină', 'Autocunoaștere', 'Automotivare', 'Colaborare',
    'Comunicare', 'Comunicare scrisă', 'Comunicare verbală', 'Conducere',
    'Conștientizare culturală', 'Conștientizare risc', 'Creativitate',
    'Delegare', 'Dezvoltarea relațiilor', 'Educație orientată spre feedback',
    'Empatie', 'Etică profesională', 'Facilitare', 'Flexibilitate',
    'Gândire critică', 'Gândire strategică', 'Gestionarea conflictelor',
    'Gestionarea părților interesate', 'Gestionarea stresului',
    'Gestionarea timpului', 'Influențare', 'Inițiativă', 'Inovație',
    'Inteligență emoțională', 'Învățare continuă', 'Luarea deciziilor',
    'Lucru în echipă', 'Managementul oamenilor', 'Mentorat', 'Negociere',
    'Networking', 'Orientare către client', 'Organizare', 'Ownership',
    'Planificare', 'Prioritizare', 'Proactivitate', 'Profesionalism',
    'Reziliență', 'Responsabilitate', 'Rezolvare de probleme',
    'Rezolvare de situații', 'Răbdare', 'Spirit de inițiativă',
    'Spirit de colaborare', 'Transparență', 'Viziune de business',
  ];

  static const List<String> _hardSkillsEn = [
    '.NET', 'ABAP', 'Agile', 'Algorithms', 'Android', 'Angular', 'Ansible',
    'Apache Kafka', 'ASP.NET Core', 'Assembly', 'AWS', 'Azure', 'Bash',
    'BigQuery', 'Blazor', 'Blockchain', 'Bootstrap', 'Business Intelligence',
    'C', 'C#', 'C++', 'CI/CD', 'Cloud Architecture', 'Clojure', 'COBOL',
    'Computer Vision', 'CSS', 'Cybersecurity', 'Dart', 'Data Analysis',
    'Data Engineering', 'Data Modeling', 'Data Science', 'Databricks', 'Delphi',
    'DevOps', 'Django', 'Docker', 'Elasticsearch', 'ETL', 'Excel', 'FastAPI',
    'Figma', 'Firebase', 'Flask', 'Flutter', 'GCP', 'Git', 'GitHub Actions',
    'GitLab CI', 'Go', 'GraphQL', 'Groovy', 'Hadoop', 'HANA SQL', 'HTML',
    'iOS', 'Java', 'JavaScript', 'Jenkins', 'Jira', 'Julia', 'Kotlin',
    'Kubernetes', 'Laravel', 'Linux', 'Machine Learning', 'MATLAB', 'Microservices',
    'MongoDB', 'MySQL', 'NestJS', 'Network Engineering', 'Next.js', 'NLP',
    'Node.js', 'NoSQL', 'Objective-C', 'Oracle', 'Pandas', 'Perl', 'PHP',
    'Photoshop', 'PL/SQL', 'PostgreSQL', 'Power BI', 'PowerShell', 'PyTorch',
    'Python', 'QA Automation', 'Qlik', 'R', 'React', 'Redis', 'REST APIs',
    'Ruby', 'Ruby on Rails', 'Rust', 'SAP ABAP', 'SAP Analytics Cloud',
    'SAP BTP', 'SAP CAP', 'SAP Fiori', 'SAP HANA', 'SAP RAP', 'SAP UI5',
    'SASS', 'Scala', 'Scrum', 'Selenium', 'Shell Scripting', 'Snowflake',
    'Solidity', 'Spring Boot', 'SQL', 'SQL Server', 'Swift', 'Tableau',
    'Tailwind CSS', 'Terraform', 'TensorFlow', 'Testing', 'TypeScript',
    'UI/UX', 'Unix', 'Unity', 'VBA', 'Vue.js', 'Web Security', 'WordPress',
  ];

  static const List<String> _hardSkillsRo = [
    '.NET', 'ABAP', 'Agile', 'Algoritmi', 'Android', 'Angular', 'Ansible',
    'Apache Kafka', 'ASP.NET Core', 'Assembly', 'AWS', 'Azure', 'Bash',
    'BigQuery', 'Blazor', 'Blockchain', 'Bootstrap', 'Business Intelligence',
    'C', 'C#', 'C++', 'CI/CD', 'Arhitectură cloud', 'Clojure', 'COBOL',
    'Viziune computerizată', 'CSS', 'Securitate cibernetică', 'Dart',
    'Analiză de date', 'Data Engineering', 'Modelare de date', 'Data Science',
    'Databricks', 'Delphi', 'DevOps', 'Django', 'Docker', 'Elasticsearch',
    'ETL', 'Excel', 'FastAPI', 'Figma', 'Firebase', 'Flask', 'Flutter',
    'GCP', 'Git', 'GitHub Actions', 'GitLab CI', 'Go', 'GraphQL', 'Groovy',
    'Hadoop', 'HANA SQL', 'HTML', 'iOS', 'Java', 'JavaScript', 'Jenkins',
    'Jira', 'Julia', 'Kotlin', 'Kubernetes', 'Laravel', 'Linux',
    'Machine Learning', 'MATLAB', 'Microservicii', 'MongoDB', 'MySQL',
    'NestJS', 'Inginerie de rețea', 'Next.js', 'NLP', 'Node.js', 'NoSQL',
    'Objective-C', 'Oracle', 'Pandas', 'Perl', 'PHP', 'Photoshop', 'PL/SQL',
    'PostgreSQL', 'Power BI', 'PowerShell', 'PyTorch', 'Python',
    'Automatizare QA', 'Qlik', 'R', 'React', 'Redis', 'REST APIs', 'Ruby',
    'Ruby on Rails', 'Rust', 'SAP ABAP', 'SAP Analytics Cloud', 'SAP BTP',
    'SAP CAP', 'SAP Fiori', 'SAP HANA', 'SAP RAP', 'SAP UI5', 'SASS',
    'Scala', 'Scrum', 'Selenium', 'Shell Scripting', 'Snowflake', 'Solidity',
    'Spring Boot', 'SQL', 'SQL Server', 'Swift', 'Tableau', 'Tailwind CSS',
    'Terraform', 'TensorFlow', 'Testare software', 'TypeScript', 'UI/UX',
    'Unix', 'Unity', 'VBA', 'Vue.js', 'Securitate web', 'WordPress',
  ];
}
