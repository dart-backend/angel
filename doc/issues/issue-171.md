# Issue 171

Hello,
When we generate models with Angel3_orm_generator, it generates positionals parameters  and nameds parameters.
It should be interesting to have the choice.
Thank you

Here, both type of parameters are generated. We need to delete one to get  functionals classes. It seems that named parameters are privileged in Angel 3 . We could keep it. Perhaps someone need positionals parameters, that 's why i talked about the creation of an optional solution. In all cases, we should not have to delete half of parameters for each models. Thank you

I understood why i got the pb. Except of jsonb set in generated files that suit for postgre whereas mysql need json, i successed to generate tables.
