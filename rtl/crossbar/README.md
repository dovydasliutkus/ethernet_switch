
# VOQ Buffer (CIXB2)

## Notes on `i_write_en` and `i_read_en`

`i_write_en` and `i_read_en` are flattened enable buses for all VOQ pairs `(i, j)`.

For `PORTS = 4`, the mapping is:

- bit 0 -> `(0,0)`
- bit 1 -> `(0,1)`
- bit 2 -> `(0,2)`
- bit 3 -> `(0,3)`
- bit 4 -> `(1,0)`
- bit 5 -> `(1,1)`
- bit 6 -> `(1,2)`
- bit 7 -> `(1,3)`
- bit 8 -> `(2,0)`
- bit 9 -> `(2,1)`
- bit 10 -> `(2,2)`
- bit 11 -> `(2,3)`
- bit 12 -> `(3,0)`
- bit 13 -> `(3,1)`
- bit 14 -> `(3,2)`
- bit 15 -> `(3,3)`

Here, `i` is the input port and `j` is the output port. The pair `(i, j)` is converted to a single bit index with:

`bit_index = i * PORTS + j`

So the one-hot enable for a specific VOQ is:

`1 << (i * PORTS + j)`

This sets one bit in the 16-bit enable bus: the queue for input `i` going to output `j`.