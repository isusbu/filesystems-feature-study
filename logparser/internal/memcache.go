package internal

// MemCache is the memory cache for storing the counts.
type MemCache struct {
	counts map[string]int
}

// Inc a label by one.
func (m *MemCache) Inc(label string) {
	if _, ok := m.counts[label]; !ok {
		m.counts[label] = 0
	}

	m.counts[label]++
}

// Export the memory into a map of string to ints.
func (m *MemCache) Export() map[string]int {
	return m.counts
}
