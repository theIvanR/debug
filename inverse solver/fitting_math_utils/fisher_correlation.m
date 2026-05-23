function corr = fisher_correlation(F)
d = sqrt(max(diag(F), eps));
corr = F ./ (d * d.');
end