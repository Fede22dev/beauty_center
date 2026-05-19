enum BlockedSlotRecurrence {
  none('Nessuna'),
  daily('Ogni giorno'),
  weekly('Ogni settimana'),
  monthly('Ogni mese');

  const BlockedSlotRecurrence(this.label);

  final String label;
}
